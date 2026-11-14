<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::unprepared(<<<'SQL'
CREATE OR REPLACE FUNCTION gnu.affectation_responsable_notes(cid bigint, uid bigint) RETURNS bigint
LANGUAGE sql STABLE SET search_path=gnu,pg_catalog AS $$
    SELECT a.id
    FROM affectation a
    JOIN matiere m ON m.id = a.matiere_id
    JOIN responsable_note_ue rnu
      ON rnu.classe_id = a.classe_id
     AND rnu.ue_id = m.ue_id
     AND rnu.enseignant_id = a.enseignant_id
    WHERE a.classe_id = cid AND m.ue_id = uid AND a.actif = true
    ORDER BY m.rang_ec, a.id
    LIMIT 1
$$;

CREATE OR REPLACE FUNCTION gnu.verifier_plan_notes_ue_unique() RETURNS trigger
LANGUAGE plpgsql SET search_path=gnu,pg_catalog AS $$
DECLARE classe_courante bigint; ue_courante bigint; ancre bigint;
BEGIN
    IF NEW.portee <> 'CLASSE' THEN RETURN NEW; END IF;
    SELECT a.classe_id, m.ue_id INTO classe_courante, ue_courante
    FROM affectation a JOIN matiere m ON m.id = a.matiere_id
    WHERE a.id = NEW.affectation_id;
    ancre := affectation_responsable_notes(classe_courante, ue_courante);
    PERFORM exiger(ancre IS NOT NULL AND NEW.affectation_id = ancre,
        'Le plan normal doit être celui du responsable unique de l’UE.');
    IF NEW.statut_plan = 'ACTIF' THEN
        PERFORM exiger(NOT EXISTS (
            SELECT 1 FROM plan_evaluation p
            WHERE p.affectation_id = NEW.affectation_id
              AND p.portee = 'CLASSE' AND p.statut_plan = 'ACTIF'
              AND p.id <> NEW.id
        ), 'Une seule grille active est autorisée pour cette UE et cette classe.');
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION gnu.verifier_evaluation_notes_ue_unique() RETURNS trigger
LANGUAGE plpgsql SET search_path=gnu,pg_catalog AS $$
DECLARE classe_courante bigint; ue_courante bigint; ancre bigint;
BEGIN
    IF NEW.mode_evaluation <> 'NORMALE' THEN RETURN NEW; END IF;
    SELECT a.classe_id, m.ue_id INTO classe_courante, ue_courante
    FROM affectation a JOIN matiere m ON m.id = a.matiere_id
    WHERE a.id = NEW.affectation_id;
    ancre := affectation_responsable_notes(classe_courante, ue_courante);
    PERFORM exiger(ancre IS NOT NULL AND NEW.affectation_id = ancre,
        'Une évaluation normale doit être rattachée au carnet unique de l’UE.');
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION gnu.verifier_type_evaluation_unique_par_plan() RETURNS trigger
LANGUAGE plpgsql SET search_path=gnu,pg_catalog AS $$
DECLARE type_courant text;
BEGIN
    SELECT type_eval::text INTO type_courant FROM evaluation WHERE id = NEW.evaluation_id;
    PERFORM exiger(NOT EXISTS (
        SELECT 1 FROM ligne_plan lp JOIN evaluation ev ON ev.id = lp.evaluation_id
        WHERE lp.plan_id = NEW.plan_id
          AND lp.evaluation_id <> NEW.evaluation_id
          AND ev.type_eval::text = type_courant
    ), 'Un plan UE ne peut contenir qu’une évaluation de chaque type.');
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS verifier_plan_notes_ue_unique ON gnu.plan_evaluation;
CREATE TRIGGER verifier_plan_notes_ue_unique
    BEFORE INSERT OR UPDATE ON gnu.plan_evaluation
    FOR EACH ROW EXECUTE FUNCTION gnu.verifier_plan_notes_ue_unique();
DROP TRIGGER IF EXISTS verifier_evaluation_notes_ue_unique ON gnu.evaluation;
CREATE TRIGGER verifier_evaluation_notes_ue_unique
    BEFORE INSERT OR UPDATE ON gnu.evaluation
    FOR EACH ROW EXECUTE FUNCTION gnu.verifier_evaluation_notes_ue_unique();
DROP TRIGGER IF EXISTS verifier_type_evaluation_unique_par_plan ON gnu.ligne_plan;
CREATE TRIGGER verifier_type_evaluation_unique_par_plan
    BEFORE INSERT OR UPDATE ON gnu.ligne_plan
    FOR EACH ROW EXECUTE FUNCTION gnu.verifier_type_evaluation_unique_par_plan();

CREATE OR REPLACE FUNCTION gnu.calculer_ec(iu bigint, mid bigint) RETURNS jsonb
LANGUAGE plpgsql SET search_path=gnu,pg_catalog AS $$
DECLARE ci contexte_inscription; p plan_evaluation; l record; n note; c candidature_rattrapage;
        resultat numeric:=0; elim boolean:=false; sources jsonb:='[]'; a affectation; total numeric;
BEGIN
    SELECT * INTO ci FROM contexte_inscription WHERE inscription_ue_id=iu;
    PERFORM exiger(EXISTS(SELECT 1 FROM matiere WHERE id=mid AND ue_id=ci.ue_id),'EC étranger à inscription');
    SELECT * INTO a FROM affectation WHERE id=affectation_responsable_notes(ci.classe_id,ci.ue_id);
    IF a.id IS NULL THEN
        RETURN jsonb_build_object('matiere_id',mid,'code_m',(SELECT code_m FROM matiere WHERE id=mid),
            'credit',(SELECT credit_matiere FROM matiere WHERE id=mid),'plan_id',NULL,'version_plan',NULL,
            'sources',sources,'el',true,'brut',NULL,'arrondi',NULL,'motif_elimination','PLAN_EVALUATION_MANQUANT');
    END IF;
    SELECT * INTO p FROM plan_evaluation WHERE affectation_id=a.id AND statut_plan='ACTIF'
      AND (portee='CLASSE' OR inscription_ue_id=iu)
    ORDER BY (portee='ETUDIANT') DESC LIMIT 1;
    IF p.id IS NULL THEN
        RETURN jsonb_build_object('matiere_id',mid,'code_m',(SELECT code_m FROM matiere WHERE id=mid),
            'credit',(SELECT credit_matiere FROM matiere WHERE id=mid),'plan_id',NULL,'version_plan',NULL,
            'sources',sources,'el',true,'brut',NULL,'arrondi',NULL,'motif_elimination','PLAN_EVALUATION_MANQUANT');
    END IF;
    SELECT sum(poids_evaluation) INTO total FROM ligne_plan WHERE plan_id=p.id AND retenue;
    IF total IS DISTINCT FROM 100 OR NOT plan_evaluation_types_valid(p.id) THEN
        RETURN jsonb_build_object('matiere_id',mid,'code_m',(SELECT code_m FROM matiere WHERE id=mid),
            'credit',(SELECT credit_matiere FROM matiere WHERE id=mid),'plan_id',p.id,'version_plan',p.version_plan,
            'sources',sources,'el',true,'brut',NULL,'arrondi',NULL,'motif_elimination','PONDERATION_INVALIDE');
    END IF;
    FOR l IN SELECT * FROM ligne_plan WHERE plan_id=p.id AND retenue ORDER BY id LOOP
        SELECT * INTO c FROM candidature_rattrapage
        WHERE inscription_ue_id=iu AND evaluation_origine_id=l.evaluation_id AND date_consommation IS NOT NULL;
        SELECT * INTO n FROM note
        WHERE inscription_ue_id=iu AND evaluation_id=coalesce(c.evaluation_rattrapage_id,l.evaluation_id);
        IF n.id IS NULL OR n.statut_note<>'VALIDEE' OR n.situation<>'NUMERIQUE' OR n.valeur_note IS NULL THEN
            elim:=true;
            sources:=sources||jsonb_build_array(jsonb_build_object('evaluation_origine_id',l.evaluation_id,
                'evaluation_id',n.evaluation_id,'note_id',n.id,'version_note',n.version_note,
                'valeur',n.valeur_note,'situation',coalesce(n.situation,'MANQUANTE'),
                'statut_note',coalesce(n.statut_note,'ABSENTE'),
                'poids',gnu.poids_officiel_evaluation(p.id,l.evaluation_id),
                'poids_plan',l.poids_evaluation,'el',true));
            CONTINUE;
        END IF;
        resultat:=resultat+n.valeur_note*gnu.poids_officiel_evaluation(p.id,l.evaluation_id)/100;
        sources:=sources||jsonb_build_array(jsonb_build_object('evaluation_origine_id',l.evaluation_id,
            'evaluation_id',n.evaluation_id,'note_id',n.id,'version_note',n.version_note,
            'valeur',n.valeur_note,'situation',n.situation,
            'poids',gnu.poids_officiel_evaluation(p.id,l.evaluation_id),
            'poids_plan',l.poids_evaluation,'el',false));
    END LOOP;
    RETURN jsonb_build_object('matiere_id',mid,'code_m',(SELECT code_m FROM matiere WHERE id=mid),
        'credit',(SELECT credit_matiere FROM matiere WHERE id=mid),'plan_id',p.id,'version_plan',p.version_plan,
        'sources',sources,'el',elim,'brut',CASE WHEN elim THEN NULL ELSE resultat*5 END,
        'arrondi',CASE WHEN elim THEN NULL ELSE round(resultat*5,2) END);
END;
$$;

SQL);

        $provisional = DB::scalar("SELECT pg_get_functiondef('gnu.calculer_ec_provisoire(bigint,bigint)'::regprocedure)");
        $provisional = $this->replaceCanonicalAssignment($provisional);
        DB::unprepared($provisional);

        DB::unprepared(<<<'SQL'

REVOKE ALL ON FUNCTION gnu.affectation_responsable_notes(bigint,bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION gnu.affectation_responsable_notes(bigint,bigint) TO gnu_app;
GRANT EXECUTE ON FUNCTION gnu.calculer_ec(bigint,bigint) TO gnu_app;
SQL);
    }

    public function down(): void
    {
        throw new RuntimeException('La règle de notation unique par UE est versionnée. Restaurez explicitement la base pour revenir en arrière.');
    }

    private function replaceCanonicalAssignment(string $definition): string
    {
        $pattern = '~SELECT\s+\*\s+INTO\s+a\s+FROM\s+affectation\s+WHERE\s+matiere_id\s*=\s*mid\s+AND\s+classe_id\s*=\s*ci\.classe_id\s+AND\s+actif\s*;~i';
        $replacement = 'SELECT * INTO a FROM affectation WHERE id=gnu.affectation_responsable_notes(ci.classe_id,ci.ue_id);';
        $count = 0;
        $updated = preg_replace($pattern, $replacement, $definition, 1, $count);

        if ($updated === null || $count !== 1) {
            throw new RuntimeException('Impossible de faire pointer le calcul provisoire vers l’unique grille de l’UE.');
        }

        return $updated;
    }
};
