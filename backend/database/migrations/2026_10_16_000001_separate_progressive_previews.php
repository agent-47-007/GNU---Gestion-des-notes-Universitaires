<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        $required = DB::selectOne("SELECT to_regclass('gnu.contexte_inscription') AS contexte_inscription, to_regclass('gnu.plan_evaluation') AS plan_evaluation, to_regclass('gnu.note') AS note, to_regclass('gnu.utilisateur') AS utilisateur, to_regclass('gnu.inscription_classe') AS inscription_classe");
        $appRoleExists = filter_var(DB::scalar("SELECT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'gnu_app')"), FILTER_VALIDATE_BOOLEAN);
        if ($required === null || in_array(null, (array) $required, true) || ! $appRoleExists) {
            throw new RuntimeException('Le schéma académique GNU attendu est absent. Vérifiez la base avant cette migration.');
        }
        if (DB::getDriverName() !== 'pgsql') {
            throw new RuntimeException('Cette migration doit être exécutée sur PostgreSQL.');
        }

        DB::unprepared(<<<'SQL'
CREATE OR REPLACE FUNCTION gnu.calculer_ec_provisoire(iu bigint, mid bigint) RETURNS jsonb
LANGUAGE plpgsql SET search_path=gnu,pg_catalog AS $$
DECLARE ci contexte_inscription; p plan_evaluation; l record; n note; c candidature_rattrapage;
 resultat numeric:=0; elim boolean:=false; attente boolean:=false; sources jsonb:='[]'; a affectation; total numeric;
BEGIN
 SELECT * INTO ci FROM contexte_inscription WHERE inscription_ue_id=iu;
 PERFORM exiger(ci.inscription_ue_id IS NOT NULL AND EXISTS(SELECT 1 FROM matiere WHERE id=mid AND ue_id=ci.ue_id),'EC étranger à inscription');
 SELECT * INTO a FROM affectation WHERE matiere_id=mid AND classe_id=ci.classe_id AND actif;
 SELECT * INTO p FROM plan_evaluation WHERE affectation_id=a.id AND statut_plan='ACTIF' AND (portee='CLASSE' OR inscription_ue_id=iu) ORDER BY (portee='ETUDIANT') DESC LIMIT 1;
 IF p.id IS NULL THEN
  RETURN jsonb_build_object('matiere_id',mid,'code_m',(SELECT code_m FROM matiere WHERE id=mid),'credit',(SELECT credit_matiere FROM matiere WHERE id=mid),'plan_id',NULL,'version_plan',NULL,'sources',sources,'en_attente',true,'el',false,'brut',NULL,'arrondi',NULL,'motif_attente','PLAN_EVALUATION_MANQUANT');
 END IF;
 SELECT sum(poids_evaluation) INTO total FROM ligne_plan WHERE plan_id=p.id AND retenue;
 IF total IS DISTINCT FROM 100 THEN
  RETURN jsonb_build_object('matiere_id',mid,'code_m',(SELECT code_m FROM matiere WHERE id=mid),'credit',(SELECT credit_matiere FROM matiere WHERE id=mid),'plan_id',p.id,'version_plan',p.version_plan,'sources',sources,'en_attente',true,'el',false,'brut',NULL,'arrondi',NULL,'motif_attente','PONDERATION_INVALIDE');
 END IF;
 FOR l IN SELECT * FROM ligne_plan WHERE plan_id=p.id AND retenue ORDER BY id LOOP
  SELECT * INTO c FROM candidature_rattrapage WHERE inscription_ue_id=iu AND evaluation_origine_id=l.evaluation_id AND date_consommation IS NOT NULL;
  SELECT * INTO n FROM note WHERE inscription_ue_id=iu AND evaluation_id=coalesce(c.evaluation_rattrapage_id,l.evaluation_id);
  IF n.id IS NULL OR n.statut_note<>'VALIDEE' OR n.situation='MANQUANTE' OR (n.situation='NUMERIQUE' AND n.valeur_note IS NULL) THEN
   attente:=true;
   sources:=sources||jsonb_build_array(jsonb_build_object('evaluation_origine_id',l.evaluation_id,'evaluation_id',n.evaluation_id,'note_id',n.id,'version_note',n.version_note,'valeur',n.valeur_note,'situation',coalesce(n.situation,'MANQUANTE'),'statut_note',coalesce(n.statut_note,'ABSENTE'),'poids',l.poids_evaluation,'en_attente',true,'el',false));
   CONTINUE;
  END IF;
  IF n.situation='ABSENTE' THEN
   elim:=true;
   sources:=sources||jsonb_build_array(jsonb_build_object('evaluation_origine_id',l.evaluation_id,'evaluation_id',n.evaluation_id,'note_id',n.id,'version_note',n.version_note,'valeur',n.valeur_note,'situation',n.situation,'statut_note',n.statut_note,'poids',l.poids_evaluation,'en_attente',false,'el',true));
   CONTINUE;
  END IF;
  IF n.situation<>'NUMERIQUE' THEN
   attente:=true;
   sources:=sources||jsonb_build_array(jsonb_build_object('evaluation_origine_id',l.evaluation_id,'evaluation_id',n.evaluation_id,'note_id',n.id,'version_note',n.version_note,'valeur',n.valeur_note,'situation',n.situation,'statut_note',n.statut_note,'poids',l.poids_evaluation,'en_attente',true,'el',false));
   CONTINUE;
  END IF;
  resultat:=resultat+n.valeur_note*l.poids_evaluation/100;
  sources:=sources||jsonb_build_array(jsonb_build_object('evaluation_origine_id',l.evaluation_id,'evaluation_id',n.evaluation_id,'note_id',n.id,'version_note',n.version_note,'valeur',n.valeur_note,'situation',n.situation,'statut_note',n.statut_note,'poids',l.poids_evaluation,'en_attente',false,'el',false));
 END LOOP;
 RETURN jsonb_build_object('matiere_id',mid,'code_m',(SELECT code_m FROM matiere WHERE id=mid),'credit',(SELECT credit_matiere FROM matiere WHERE id=mid),'plan_id',p.id,'version_plan',p.version_plan,'sources',sources,'en_attente',attente,'el',elim,'brut',CASE WHEN attente OR elim THEN NULL ELSE resultat*5 END,'arrondi',CASE WHEN attente OR elim THEN NULL ELSE round(resultat*5,2) END);
END $$;

CREATE OR REPLACE FUNCTION gnu.calculer_ue_provisoire(iuid bigint) RETURNS jsonb
LANGUAGE plpgsql SET search_path=gnu,pg_catalog AS $$
DECLARE iu inscription_ue; u ue; m matiere; r jsonb; ecs jsonb:='[]'; total numeric:=0; credits numeric:=0; elim boolean:=false; attente boolean:=false; valeur numeric; brut numeric;
BEGIN
 SELECT * INTO iu FROM inscription_ue WHERE id=iuid;
 SELECT * INTO u FROM ue WHERE id=iu.ue_id;
 PERFORM exiger(iu.id IS NOT NULL AND iu.statut_inscription='VALIDEE','Inscription UE non validée');
 IF iu.type_inscription='CONSERVEE' THEN
  SELECT value INTO r FROM bulletin b CROSS JOIN LATERAL jsonb_array_elements(b.contenu_fige->'ues') WHERE b.id=iu.bulletin_source_id AND (value->>'ue_id')::bigint=iu.ue_source_id;
  RETURN r||jsonb_build_object('ue_id',iu.ue_id,'inscription_ue_id',iu.id,'credit',u.credit_ue,'semestre',u.numero_semestre,'source_bulletin_id',iu.bulletin_source_id,'ue_source_id',iu.ue_source_id,'en_attente',false);
 END IF;
 FOR m IN SELECT * FROM matiere WHERE ue_id=u.id ORDER BY rang_ec LOOP
  r:=calculer_ec_provisoire(iuid,m.id);
  ecs:=ecs||jsonb_build_array(r);
  elim:=elim OR coalesce((r->>'el')::boolean,false);
  attente:=attente OR coalesce((r->>'en_attente')::boolean,false);
  total:=total+coalesce((r->>'brut')::numeric,0)*m.credit_matiere;
  credits:=credits+m.credit_matiere;
 END LOOP;
 PERFORM exiger(credits>0,'UE sans EC');
 brut:=total/credits;
 valeur:=round(brut,2);
 RETURN jsonb_build_object('inscription_ue_id',iu.id,'ue_id',u.id,'code_ue',u.code_ue,'version_programme',u.version_programme,'credit',u.credit_ue,'semestre',u.numero_semestre,'ecs',ecs,'en_attente',attente,'el',elim,'brut',CASE WHEN attente OR elim THEN NULL ELSE brut END,'arrondi',CASE WHEN attente OR elim THEN NULL ELSE valeur END,'grade',CASE WHEN attente THEN 'EN ATTENTE' WHEN elim THEN 'EL' ELSE grade_ue(valeur) END,'points',CASE WHEN attente THEN NULL WHEN elim THEN 0 ELSE points_ue(valeur) END);
END $$;

CREATE OR REPLACE FUNCTION gnu.previsualiser_bulletin(icid bigint, per text) RETURNS jsonb
LANGUAGE plpgsql SET search_path=gnu,pg_catalog AS $$
DECLARE ic inscription_classe; c classe; u ue; iu inscription_ue; r jsonb; liste jsonb:='[]'; numer numeric:=0; den numeric:=0; n1 numeric:=0; d1 numeric:=0; n2 numeric:=0; d2 numeric:=0; admissible boolean:=true; eliminee boolean:=false; attendu integer:=0; complet integer:=0; credit_attendu numeric:=0;
BEGIN
 PERFORM exiger(per IN ('S1','S2','ANNUELLE'),'Période inconnue');
 SELECT * INTO ic FROM inscription_classe WHERE id=icid;
 SELECT * INTO c FROM classe WHERE id=ic.classe_id;
 PERFORM exiger(ic.id IS NOT NULL AND ic.statut_inscription='VALIDEE','Inscription de classe non validée');
 FOR u IN
  SELECT ue.* FROM ue WHERE ue.niveau_id=c.niveau_id AND ue.version_programme=c.version_programme AND ue.statut_catalogue='ACTIF'
   AND (per='ANNUELLE' OR ue.numero_semestre=CASE per WHEN 'S1' THEN 1 WHEN 'S2' THEN 2 END)
   AND (ue.categorie_ue='FONDAMENTALE' OR EXISTS(SELECT 1 FROM inscription_ue x WHERE x.inscription_classe_id=icid AND x.ue_id=ue.id AND x.statut_inscription='VALIDEE'))
  ORDER BY ue.numero_semestre,ue.id
 LOOP
  SELECT * INTO iu FROM inscription_ue WHERE inscription_classe_id=icid AND ue_id=u.id AND statut_inscription='VALIDEE';
  credit_attendu:=credit_attendu+u.credit_ue;
  IF iu.id IS NULL THEN
   attendu:=attendu+1;
   liste:=liste||jsonb_build_array(jsonb_build_object('ue_id',u.id,'code_ue',u.code_ue,'intitule_ue',u.intitule_ue,'credit',u.credit_ue,'semestre',u.numero_semestre,'en_attente',true,'statut','INSCRIPTION_REQUISE','el',false,'arrondi',NULL,'grade','EN ATTENTE','points',NULL,'ecs','[]'::jsonb));
   CONTINUE;
  END IF;
  r:=calculer_ue_provisoire(iu.id);
  liste:=liste||jsonb_build_array(r);
  IF coalesce((r->>'en_attente')::boolean,false) THEN
   attendu:=attendu+1;
   CONTINUE;
  END IF;
  complet:=complet+1;
  numer:=numer+coalesce((r->>'points')::numeric,0)*(r->>'credit')::numeric;
  den:=den+(r->>'credit')::numeric;
  IF (r->>'semestre')::integer=1 THEN
   n1:=n1+coalesce((r->>'points')::numeric,0)*(r->>'credit')::numeric;
   d1:=d1+(r->>'credit')::numeric;
  ELSE
   n2:=n2+coalesce((r->>'points')::numeric,0)*(r->>'credit')::numeric;
   d2:=d2+(r->>'credit')::numeric;
  END IF;
  eliminee:=eliminee OR coalesce((r->>'el')::boolean,false);
  admissible:=admissible AND NOT coalesce((r->>'el')::boolean,false) AND coalesce((r->>'arrondi')::numeric>=35,false);
 END LOOP;
 RETURN jsonb_build_object(
  'schema_version',1,'inscription_classe_id',icid,'periode',per,'ues',liste,
  'pret',attendu=0 AND den>0,'ues_completees',complet,'ues_en_attente',attendu,
  'somme_points_credits',numer,'total_credits',den,'credits_attendus',credit_attendu,
  'mgp_s1',round(n1/nullif(d1,0),2),'mgp_s2',round(n2/nullif(d2,0),2),
  'mgp_total',CASE WHEN per='ANNUELLE' THEN round(numer/nullif(den,0),2) ELSE NULL END,
  'decision_admission',CASE WHEN per<>'ANNUELLE' THEN 'NON_APPLICABLE' WHEN attendu>0 OR den=0 THEN 'EN_COURS' WHEN eliminee OR NOT admissible OR numer<2*den THEN 'ECHEC' ELSE 'ADMIS' END,
  'identite',(SELECT jsonb_build_object('matricule',e.matricule,'nom',us.nom,'prenom',us.prenom,'classe',c.code_classe,'annee_id',c.annee_id) FROM etudiant e JOIN utilisateur us ON us.id=e.utilisateur_id WHERE e.id=ic.etudiant_id),
  'regles',jsonb_build_object('version','GNU-1.5','arrondi','UE_2_DECIMALES_MGP_2_DECIMALES','el_points',0,'admission_ue_min',35,'admission_mgp_min',2),
  'bareme',(SELECT jsonb_agg(jsonb_build_object('minimum',v,'grade',grade_ue(v::numeric),'points',points_ue(v::numeric)) ORDER BY v) FROM unnest(ARRAY[0,30,35,40,45,50,55,60,65,70,75,80]) v)
 );
END $$;

REVOKE ALL ON FUNCTION gnu.calculer_ec_provisoire(bigint,bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION gnu.calculer_ue_provisoire(bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION gnu.previsualiser_bulletin(bigint,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION gnu.calculer_ec_provisoire(bigint,bigint) TO gnu_app;
GRANT EXECUTE ON FUNCTION gnu.calculer_ue_provisoire(bigint) TO gnu_app;
GRANT EXECUTE ON FUNCTION gnu.previsualiser_bulletin(bigint,text) TO gnu_app;
SQL);
    }

    public function down(): void
    {
        throw new RuntimeException('La séparation des calculs provisoire et officiel doit être annulée par une migration métier contrôlée.');
    }
};
