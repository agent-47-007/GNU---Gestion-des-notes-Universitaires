<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        if (DB::getDriverName() !== 'pgsql') {
            throw new RuntimeException('Cette migration doit être exécutée sur PostgreSQL.');
        }

        DB::unprepared(<<<'SQL'
CREATE OR REPLACE FUNCTION gnu.plan_evaluation_types_valid(pid bigint) RETURNS boolean
LANGUAGE sql STABLE SET search_path=gnu,pg_catalog AS $$
 SELECT coalesce(bool_and(e.type_eval::text IN ('CC','TP','TPE','SN')),false)
    AND coalesce(bool_or(e.type_eval::text='CC'),false)
    AND coalesce(bool_or(e.type_eval::text='SN'),false)
    AND NOT (coalesce(bool_or(e.type_eval::text='TP'),false) AND coalesce(bool_or(e.type_eval::text='TPE'),false))
 FROM ligne_plan lp JOIN evaluation e ON e.id=lp.evaluation_id
 WHERE lp.plan_id=pid AND lp.retenue
$$;

CREATE OR REPLACE FUNCTION gnu.poids_officiel_evaluation(pid bigint, eid bigint) RETURNS numeric
LANGUAGE plpgsql STABLE SET search_path=gnu,pg_catalog AS $$
DECLARE type_eval_courant text; poids_type numeric; poids_officiel numeric; avec_tpe boolean; avec_tp boolean;
BEGIN
 IF NOT plan_evaluation_types_valid(pid) THEN RETURN NULL; END IF;
 SELECT e.type_eval::text INTO type_eval_courant
 FROM ligne_plan lp JOIN evaluation e ON e.id=lp.evaluation_id
 WHERE lp.plan_id=pid AND lp.evaluation_id=eid AND lp.retenue;
 IF type_eval_courant IS NULL THEN RETURN NULL; END IF;

 SELECT coalesce(bool_or(e.type_eval::text='TPE'),false), coalesce(bool_or(e.type_eval::text='TP'),false)
 INTO avec_tpe, avec_tp
 FROM ligne_plan lp JOIN evaluation e ON e.id=lp.evaluation_id
 WHERE lp.plan_id=pid AND lp.retenue;

 poids_officiel:=CASE
  WHEN avec_tpe THEN CASE type_eval_courant WHEN 'CC' THEN 20 WHEN 'TPE' THEN 20 WHEN 'SN' THEN 60 ELSE 0 END
  WHEN avec_tp THEN CASE type_eval_courant WHEN 'CC' THEN 20 WHEN 'TP' THEN 30 WHEN 'SN' THEN 50 ELSE 0 END
  ELSE CASE type_eval_courant WHEN 'CC' THEN 30 WHEN 'SN' THEN 70 ELSE 0 END
 END;
 SELECT sum(lp.poids_evaluation) INTO poids_type
 FROM ligne_plan lp JOIN evaluation e ON e.id=lp.evaluation_id
 WHERE lp.plan_id=pid AND lp.retenue AND e.type_eval::text=type_eval_courant;
 RETURN poids_officiel* (SELECT lp.poids_evaluation FROM ligne_plan lp WHERE lp.plan_id=pid AND lp.evaluation_id=eid AND lp.retenue) / nullif(poids_type,0);
END $$;
SQL);

        $official = DB::scalar("SELECT pg_get_functiondef('gnu.calculer_ec(bigint,bigint)'::regprocedure)");
        $official = $this->replaceExactlyOnce(
            $official,
            '~resultat\s*:=\s*resultat\s*\+\s*n\.valeur_note\s*\*\s*l\.poids_evaluation\s*/\s*100\s*;~i',
            'resultat:=resultat+n.valeur_note*gnu.poids_officiel_evaluation(p.id,l.evaluation_id)/100;',
            'formule officielle de l’EC',
        );
        $official = $this->replaceExactlyOnce(
            $official,
            "~'poids'\\s*,\\s*l\\.poids_evaluation~i",
            "'poids',gnu.poids_officiel_evaluation(p.id,l.evaluation_id),'poids_plan',l.poids_evaluation",
            'source de pondération officielle',
        );
        $official = $this->replaceExactlyOnce(
            $official,
            '~IF\s+total\s+IS\s+DISTINCT\s+FROM\s+100\s+THEN~i',
            'IF total IS DISTINCT FROM 100 OR NOT gnu.plan_evaluation_types_valid(p.id) THEN',
            'contrôle du plan de calcul officiel',
        );
        if (! preg_match("~'brut'\\s*,\\s*CASE\\s+WHEN\\s+elim\\s+THEN\\s+NULL\\s+ELSE\\s+resultat\\s*\\*\\s*5\\s+END\\s*,\\s*'arrondi'\\s*,\\s*CASE\\s+WHEN\\s+elim\\s+THEN\\s+NULL\\s+ELSE\\s+round\\s*\\(\\s*resultat\\s*\\*\\s*5\\s*,\\s*2\\s*\\)\\s+END~i", $official)) {
            $official = $this->replaceExactlyOnce(
                $official,
                "~'brut'\\s*,\\s*CASE\\s+WHEN\\s+elim\\s+THEN\\s+NULL\\s+ELSE\\s+resultat\\s+END\\s*,\\s*'arrondi'\\s*,\\s*CASE\\s+WHEN\\s+elim\\s+THEN\\s+NULL\\s+ELSE\\s+round\\s*\\(\\s*resultat\\s*,\\s*2\\s*\\)\\s+END~i",
                "'brut',CASE WHEN elim THEN NULL ELSE resultat*5 END,'arrondi',CASE WHEN elim THEN NULL ELSE round(resultat*5,2) END",
                'échelle du résultat officiel de l’EC',
            );
        }
        DB::unprepared($official);

        $preview = DB::scalar("SELECT pg_get_functiondef('gnu.calculer_ec_provisoire(bigint,bigint)'::regprocedure)");
        $preview = $this->replaceExactlyOnce(
            $preview,
            '~resultat\s*:=\s*resultat\s*\+\s*n\.valeur_note\s*\*\s*l\.poids_evaluation\s*/\s*100\s*;~i',
            'resultat:=resultat+n.valeur_note*gnu.poids_officiel_evaluation(p.id,l.evaluation_id)/100;',
            'formule provisoire de l’EC',
        );
        $preview = $this->replaceExactlyOnce(
            $preview,
            "~'poids'\\s*,\\s*l\\.poids_evaluation~i",
            "'poids',gnu.poids_officiel_evaluation(p.id,l.evaluation_id),'poids_plan',l.poids_evaluation",
            'source de pondération provisoire',
        );
        $preview = $this->replaceExactlyOnce(
            $preview,
            '~IF\s+total\s+IS\s+DISTINCT\s+FROM\s+100\s+THEN~i',
            'IF total IS DISTINCT FROM 100 OR NOT gnu.plan_evaluation_types_valid(p.id) THEN',
            'contrôle du plan de calcul provisoire',
        );
        DB::unprepared($preview);

        foreach ([
            'gnu.calculer_bulletin(bigint,text)',
            'gnu.previsualiser_bulletin(bigint,text)',
            'gnu.controle_publication()',
        ] as $signature) {
            $definition = DB::scalar('SELECT pg_get_functiondef(?::regprocedure)', [$signature]);
            $updated = str_replace(['GNU-1.3', 'GNU-1.4', 'GNU-1.5'], 'GNU-1.6', $definition);
            if ($updated !== $definition) {
                DB::unprepared($updated);
            }
        }

        DB::unprepared(<<<'SQL'
REVOKE ALL ON FUNCTION gnu.plan_evaluation_types_valid(bigint), gnu.poids_officiel_evaluation(bigint,bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION gnu.plan_evaluation_types_valid(bigint), gnu.poids_officiel_evaluation(bigint,bigint) TO gnu_app;
SQL);
    }

    public function down(): void
    {
        throw new RuntimeException('Les règles de notation officielles sont versionnées; restaurez explicitement la base pour revenir en arrière.');
    }

    private function replaceExactlyOnce(string $source, string $pattern, string $replacement, string $description): string
    {
        $count = 0;
        $updated = preg_replace($pattern, $replacement, $source, 1, $count);
        if ($updated === null || $count !== 1) {
            throw new RuntimeException("Impossible de repérer exactement une fois le {$description}; la migration a été interrompue sans appliquer cette étape.");
        }

        return $updated;
    }
};
