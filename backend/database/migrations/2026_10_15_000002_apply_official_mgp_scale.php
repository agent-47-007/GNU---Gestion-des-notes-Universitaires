<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        $required = DB::selectOne("SELECT to_regprocedure('gnu.calculer_ec(bigint,bigint)') AS calculer_ec, to_regprocedure('gnu.calculer_ue(bigint)') AS calculer_ue, to_regprocedure('gnu.calculer_bulletin(bigint,text)') AS calculer_bulletin, to_regprocedure('gnu.controle_publication()') AS controle_publication");
        if ($required === null || in_array(null, (array) $required, true)) {
            throw new RuntimeException('Le schéma GNU attendu est absent ou incomplet. Appliquez cette migration uniquement après vérification du DDL institutionnel.');
        }

        DB::unprepared(<<<'SQL'
CREATE OR REPLACE FUNCTION gnu.grade_ue(n numeric) RETURNS text
LANGUAGE sql IMMUTABLE STRICT SET search_path=gnu,pg_catalog AS $$
 SELECT CASE
  WHEN n NOT BETWEEN 0 AND 100 THEN NULL
  WHEN n >= 80 THEN 'A'
  WHEN n >= 75 THEN 'A-'
  WHEN n >= 70 THEN 'B+'
  WHEN n >= 65 THEN 'B'
  WHEN n >= 60 THEN 'B-'
  WHEN n >= 55 THEN 'C+'
  WHEN n >= 50 THEN 'C'
  WHEN n >= 45 THEN 'C-'
  WHEN n >= 40 THEN 'D+'
  WHEN n >= 35 THEN 'D'
  WHEN n >= 30 THEN 'E'
  ELSE 'F'
 END
$$;
CREATE OR REPLACE FUNCTION gnu.grade_ue(n integer) RETURNS text
LANGUAGE sql IMMUTABLE STRICT SET search_path=gnu,pg_catalog AS $$
 SELECT gnu.grade_ue(n::numeric)
$$;
CREATE OR REPLACE FUNCTION gnu.points_ue(n numeric) RETURNS numeric
LANGUAGE sql IMMUTABLE STRICT SET search_path=gnu,pg_catalog AS $$
 SELECT CASE
  WHEN n NOT BETWEEN 0 AND 100 THEN NULL
  WHEN n >= 80 THEN 4.00
  WHEN n >= 75 THEN 3.70
  WHEN n >= 70 THEN 3.30
  WHEN n >= 65 THEN 3.00
  WHEN n >= 60 THEN 2.70
  WHEN n >= 55 THEN 2.30
  WHEN n >= 50 THEN 2.00
  WHEN n >= 45 THEN 1.70
  WHEN n >= 40 THEN 1.30
  WHEN n >= 35 THEN 1.00
  ELSE 0.00
 END
$$;
CREATE OR REPLACE FUNCTION gnu.points_ue(n integer) RETURNS numeric
LANGUAGE sql IMMUTABLE STRICT SET search_path=gnu,pg_catalog AS $$
 SELECT gnu.points_ue(n::numeric)
$$;

CREATE OR REPLACE FUNCTION gnu.calculer_ec(iu bigint, mid bigint) RETURNS jsonb
LANGUAGE plpgsql SET search_path=gnu,pg_catalog AS $$
DECLARE ci contexte_inscription; p plan_evaluation; l record; n note; c candidature_rattrapage;
 resultat numeric:=0; elim boolean:=false; sources jsonb:='[]'; a affectation; total numeric;
BEGIN
 SELECT * INTO ci FROM contexte_inscription WHERE inscription_ue_id=iu;
 PERFORM exiger(EXISTS(SELECT 1 FROM matiere WHERE id=mid AND ue_id=ci.ue_id),'EC étranger à inscription');
 SELECT * INTO a FROM affectation WHERE matiere_id=mid AND classe_id=ci.classe_id AND actif;
 SELECT * INTO p FROM plan_evaluation WHERE affectation_id=a.id AND statut_plan='ACTIF' AND (portee='CLASSE' OR inscription_ue_id=iu) ORDER BY (portee='ETUDIANT') DESC LIMIT 1;
 PERFORM exiger(p.id IS NOT NULL,'Plan actif manquant');
 SELECT sum(poids_evaluation) INTO total FROM ligne_plan WHERE plan_id=p.id AND retenue;
 PERFORM exiger(total=100,'Plan de calcul invalide');
 FOR l IN SELECT * FROM ligne_plan WHERE plan_id=p.id AND retenue ORDER BY id LOOP
  SELECT * INTO c FROM candidature_rattrapage WHERE inscription_ue_id=iu AND evaluation_origine_id=l.evaluation_id AND date_consommation IS NOT NULL;
  SELECT * INTO n FROM note WHERE inscription_ue_id=iu AND evaluation_id=coalesce(c.evaluation_rattrapage_id,l.evaluation_id);
  PERFORM exiger(n.id IS NOT NULL AND n.statut_note='VALIDEE','Note requise manquante ou non validée');
  PERFORM exiger(n.situation='NUMERIQUE','Absence ou note manquante : une décision officielle est requise avant publication');
  resultat:=resultat+n.valeur_note*l.poids_evaluation/100;
  sources:=sources||jsonb_build_array(jsonb_build_object('evaluation_origine_id',l.evaluation_id,'evaluation_id',n.evaluation_id,'note_id',n.id,'version_note',n.version_note,'valeur',n.valeur_note,'situation',n.situation,'poids',l.poids_evaluation));
 END LOOP;
 RETURN jsonb_build_object('matiere_id',mid,'code_m',(SELECT code_m FROM matiere WHERE id=mid),'credit',(SELECT credit_matiere FROM matiere WHERE id=mid),'plan_id',p.id,'version_plan',p.version_plan,'sources',sources,'el',elim,'brut',CASE WHEN elim THEN NULL ELSE resultat END,'arrondi',CASE WHEN elim THEN NULL ELSE round(resultat,2) END);
END $$;

CREATE OR REPLACE FUNCTION gnu.calculer_ue(iuid bigint) RETURNS jsonb
LANGUAGE plpgsql SET search_path=gnu,pg_catalog AS $$
DECLARE iu inscription_ue; u ue; m matiere; r jsonb; ecs jsonb:='[]'; total numeric:=0; credits numeric:=0; elim boolean:=false; valeur numeric; brut numeric;
BEGIN
 SELECT * INTO iu FROM inscription_ue WHERE id=iuid;
 SELECT * INTO u FROM ue WHERE id=iu.ue_id;
 PERFORM exiger(iu.statut_inscription='VALIDEE','Inscription UE non validée');
 IF iu.type_inscription='CONSERVEE' THEN
  SELECT value INTO r FROM bulletin b CROSS JOIN LATERAL jsonb_array_elements(b.contenu_fige->'ues') WHERE b.id=iu.bulletin_source_id AND (value->>'ue_id')::bigint=iu.ue_source_id;
  RETURN r||jsonb_build_object('ue_id',iu.ue_id,'inscription_ue_id',iu.id,'credit',u.credit_ue,'semestre',u.numero_semestre,'source_bulletin_id',iu.bulletin_source_id,'ue_source_id',iu.ue_source_id);
 END IF;
 FOR m IN SELECT * FROM matiere WHERE ue_id=u.id ORDER BY rang_ec LOOP
  r:=calculer_ec(iuid,m.id);
  ecs:=ecs||jsonb_build_array(r);
  elim:=elim OR (r->>'el')::boolean;
  total:=total+coalesce((r->>'brut')::numeric,0)*m.credit_matiere;
  credits:=credits+m.credit_matiere;
 END LOOP;
 PERFORM exiger(credits>0,'UE sans EC');
 brut:=total/credits;
 valeur:=round(brut,2);
 RETURN jsonb_build_object('inscription_ue_id',iu.id,'ue_id',u.id,'code_ue',u.code_ue,'version_programme',u.version_programme,'credit',u.credit_ue,'semestre',u.numero_semestre,'ecs',ecs,'el',elim,'brut',CASE WHEN elim THEN NULL ELSE brut END,'arrondi',CASE WHEN elim THEN NULL ELSE valeur END,'grade',CASE WHEN elim THEN 'EL' ELSE grade_ue(valeur) END,'points',CASE WHEN elim THEN 0 ELSE points_ue(valeur) END);
END $$;

CREATE OR REPLACE FUNCTION gnu.calculer_bulletin(icid bigint, per text) RETURNS jsonb
LANGUAGE plpgsql SET search_path=gnu,pg_catalog AS $$
DECLARE ic inscription_classe; c classe; iu inscription_ue; r jsonb; liste jsonb:='[]'; numer numeric:=0; den numeric:=0; n1 numeric:=0; d1 numeric:=0; n2 numeric:=0; d2 numeric:=0; admissible boolean:=true;
BEGIN
 PERFORM exiger(per IN ('S1','S2','ANNUELLE'),'Période inconnue');
 SELECT * INTO ic FROM inscription_classe WHERE id=icid;
 SELECT * INTO c FROM classe WHERE id=ic.classe_id;
 PERFORM exiger(ic.statut_inscription='VALIDEE','Inscription de classe non validée');
 PERFORM exiger(NOT EXISTS(SELECT 1 FROM ue u WHERE u.niveau_id=c.niveau_id AND u.version_programme=c.version_programme AND u.statut_catalogue='ACTIF' AND u.categorie_ue='FONDAMENTALE' AND (per='ANNUELLE' OR u.numero_semestre=CASE per WHEN 'S1' THEN 1 WHEN 'S2' THEN 2 END) AND NOT EXISTS(SELECT 1 FROM inscription_ue x WHERE x.inscription_classe_id=icid AND x.ue_id=u.id AND x.statut_inscription='VALIDEE')),'Inscription à une UE fondamentale manquante');
 FOR iu IN SELECT x.* FROM inscription_ue x JOIN ue ON ue.id=x.ue_id WHERE x.inscription_classe_id=icid AND x.statut_inscription='VALIDEE' AND (per='ANNUELLE' OR ue.numero_semestre=CASE per WHEN 'S1' THEN 1 WHEN 'S2' THEN 2 END) ORDER BY ue.numero_semestre,ue.id LOOP
  r:=calculer_ue(iu.id);
  liste:=liste||jsonb_build_array(r);
  numer:=numer+(r->>'points')::numeric*(r->>'credit')::numeric;
  den:=den+(r->>'credit')::numeric;
  IF (r->>'semestre')::integer=1 THEN
   n1:=n1+(r->>'points')::numeric*(r->>'credit')::numeric;
   d1:=d1+(r->>'credit')::numeric;
  ELSE
   n2:=n2+(r->>'points')::numeric*(r->>'credit')::numeric;
   d2:=d2+(r->>'credit')::numeric;
  END IF;
  admissible:=admissible AND NOT (r->>'el')::boolean AND coalesce((r->>'arrondi')::numeric>=35,false);
 END LOOP;
 PERFORM exiger(den>0,'Bulletin vide');
 RETURN jsonb_build_object(
  'schema_version',1,'inscription_classe_id',icid,'periode',per,'ues',liste,
  'somme_points_credits',numer,'total_credits',den,
  'mgp_s1',round(n1/nullif(d1,0),2),'mgp_s2',round(n2/nullif(d2,0),2),
  'mgp_total',CASE WHEN per='ANNUELLE' THEN round(numer/den,2) ELSE NULL END,
  'decision_admission',CASE WHEN per<>'ANNUELLE' THEN 'NON_APPLICABLE' WHEN admissible AND numer>=2*den THEN 'ADMIS' ELSE 'ECHEC' END,
  'identite',(SELECT jsonb_build_object('matricule',e.matricule,'nom',us.nom,'prenom',us.prenom,'classe',c.code_classe,'annee_id',c.annee_id) FROM etudiant e JOIN utilisateur us ON us.id=e.utilisateur_id WHERE e.id=ic.etudiant_id),
  'regles',jsonb_build_object('version','GNU-1.3','arrondi','UE_2_DECIMALES_MGP_2_DECIMALES','el_points',0,'admission_ue_min',35,'admission_mgp_min',2,'sn_ec_max_exclusif',50,'requetes_heures',48,'tentatives_ec_annee',1),
  'bareme',(SELECT jsonb_agg(jsonb_build_object('minimum',v,'grade',grade_ue(v::numeric),'points',points_ue(v::numeric)) ORDER BY v) FROM unnest(ARRAY[0,30,35,40,45,50,55,60,65,70,75,80]) v)
 );
END $$;

CREATE OR REPLACE FUNCTION gnu.controle_publication() RETURNS trigger
LANGUAGE plpgsql SET search_path=gnu,pg_catalog AS $$
DECLARE p publication; r jsonb;
BEGIN
 IF TG_TABLE_NAME='publication' THEN
  PERFORM exiger(EXISTS(SELECT 1 FROM utilisateur WHERE id=acteur() AND id=NEW.agent_publicateur_id AND role='AGENT' AND actif),'Publication réservée à l’agent connecté');
  NEW.date_publication:=statement_timestamp();
  IF NEW.publication_precedente_id IS NOT NULL THEN
   SELECT * INTO p FROM publication WHERE id=NEW.publication_precedente_id;
   PERFORM exiger(p.classe_id=NEW.classe_id AND p.periode=NEW.periode AND p.version_publication<NEW.version_publication,'Chaîne de publication incohérente');
  END IF;
 ELSE
  SELECT * INTO p FROM publication WHERE id=NEW.publication_id;
  PERFORM exiger(p.agent_publicateur_id=acteur() AND p.classe_id=(SELECT classe_id FROM inscription_classe WHERE id=NEW.inscription_classe_id),'Bulletin/publication hors périmètre');
  NEW.periode:=p.periode;
  NEW.version_bulletin:=p.version_publication;
  r:=calculer_bulletin(NEW.inscription_classe_id,p.periode);
  NEW.contenu_fige:=r;
  NEW.version_schema_contenu:=1;
  NEW.version_regles:='GNU-1.3';
  NEW.version_bareme:='GNU-MGP-100-V1';
  NEW.mgp_s1:=(r->>'mgp_s1')::numeric;
  NEW.mgp_s2:=(r->>'mgp_s2')::numeric;
  NEW.mgp_total:=(r->>'mgp_total')::numeric;
  NEW.somme_points_credits:=(r->>'somme_points_credits')::numeric;
  NEW.total_credits:=(r->>'total_credits')::numeric;
  NEW.decision_admission:=r->>'decision_admission';
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION gnu.grade_ue(numeric), gnu.points_ue(numeric) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION gnu.grade_ue(numeric), gnu.points_ue(numeric) TO gnu_app;
SQL);
    }

    public function down(): void
    {
        throw new RuntimeException('La migration MGP est une évolution métier versionnée. Le retour à l’ancien calcul nécessite une restauration SQL explicitement validée.');
    }
};
