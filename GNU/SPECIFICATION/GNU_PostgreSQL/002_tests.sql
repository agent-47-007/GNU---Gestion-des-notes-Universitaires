-- Tests de recette sur schéma fraîchement installé uniquement.
-- Toutes les données de démonstration sont annulées à la fin.
BEGIN ISOLATION LEVEL REPEATABLE READ;
SET LOCAL search_path=gnu,pg_catalog;
SELECT exiger(NOT EXISTS(SELECT 1 FROM utilisateur),'Exécuter les tests sur une base de test vide');
CREATE FUNCTION pg_temp.refuse(command text, code_attendu text DEFAULT '23514') RETURNS void LANGUAGE plpgsql AS $$
DECLARE code_recu text;
BEGIN
 BEGIN EXECUTE command;
 EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS code_recu=RETURNED_SQLSTATE;
  IF code_recu=code_attendu THEN RETURN; END IF;
  RAISE EXCEPTION 'Mauvais code %, attendu % : %',code_recu,code_attendu,SQLERRM;
 END;
 RAISE EXCEPTION 'La commande aurait dû être refusée : %',command;
END $$;
INSERT INTO universite(id,code_univ,nom_univ) OVERRIDING SYSTEM VALUE VALUES(1,'DEMO','Université de démonstration');
INSERT INTO faculte(id,code_fac,nom_fac,universite_id) OVERRIDING SYSTEM VALUE VALUES(1,'F','Faculté test',1);
INSERT INTO departement(id,code_de,nom_depart,faculte_id) OVERRIDING SYSTEM VALUE VALUES(1,'D','Département test',1);
INSERT INTO filiere(id,code_f,nom_f,departement_id) OVERRIDING SYSTEM VALUE VALUES(1,'INFO','Informatique',1);
INSERT INTO niveau(id,code_niv,cycle_niv,libelle_niv,filiere_id) OVERRIDING SYSTEM VALUE VALUES(1,'L3','LICENCE','Licence 3',1);
INSERT INTO annee_academique(id,libelle,date_debut,date_fin) OVERRIDING SYSTEM VALUE VALUES(1,'2025-2026','2025-09-01','2026-08-31'),(2,'2026-2027','2026-09-01','2027-08-31');
INSERT INTO classe(id,code_classe,niveau_id,annee_id,version_programme) OVERRIDING SYSTEM VALUE VALUES(1,'L3-2025',1,1,1),(2,'L3-2026',1,2,1);
INSERT INTO utilisateur(id,code_utilisateur,login,mot_de_passe_hash,role,actif,nom) OVERRIDING SYSTEM VALUE VALUES
(1,'E','enseignant','HASH_DE_TEST_NON_UTILISABLE','ENSEIGNANT',true,'Enseignant test'),
(2,'A','agent','HASH_DE_TEST_NON_UTILISABLE','AGENT',true,'Agent test'),
(3,'S','etudiant','HASH_DE_TEST_NON_UTILISABLE','ETUDIANT',true,'Étudiant test');
INSERT INTO enseignant(id,eid,utilisateur_id) OVERRIDING SYSTEM VALUE VALUES(1,'ENS001',1);
INSERT INTO etudiant(id,matricule,utilisateur_id) OVERRIDING SYSTEM VALUE VALUES(1,'TEST001',3);
SELECT pg_temp.refuse($q$INSERT INTO enseignant(eid,utilisateur_id) VALUES('BAD',3)$q$);
INSERT INTO inscription_classe(id,etudiant_id,classe_id,statut_redoublant,statut_inscription) OVERRIDING SYSTEM VALUE VALUES(1,1,1,false,'VALIDEE');
DO $$ DECLARE i integer; j integer; eid bigint; mid bigint; vals numeric[]:=ARRAY[49.2,60.1,34,70,40,46,80,76,65,61,55,51]; v numeric; BEGIN
 FOR i IN 1..6 LOOP
  INSERT INTO ue(id,code_ue,intitule_ue,niveau_id,version_programme,numero_semestre,categorie_ue,credit_ue,statut_catalogue) OVERRIDING SYSTEM VALUE
  VALUES(i,'D'||(100+i),'UE test '||i,1,1,CASE WHEN i<=3 THEN 1 ELSE 2 END,'FONDAMENTALE',(ARRAY[6,4,5,6,5,4])[i],'BROUILLON');
  FOR j IN 1..2 LOOP
   mid:=(i-1)*2+j;
   INSERT INTO matiere(id,code_m,intitule_matiere,ue_id,rang_ec,credit_matiere) OVERRIDING SYSTEM VALUE VALUES(mid,'M'||mid,'Matière '||mid,i,j,CASE WHEN mid=2 THEN 2 ELSE 1 END);
  END LOOP;
  UPDATE ue SET statut_catalogue='ACTIF' WHERE id=i;
  INSERT INTO inscription_ue(id,inscription_classe_id,ue_id,type_inscription,statut_inscription) OVERRIDING SYSTEM VALUE VALUES(i,1,i,'NORMALE','VALIDEE');
 END LOOP;
 PERFORM set_config('gnu.acteur_id','1',true);PERFORM set_config('gnu.motif','Saisie de démonstration',true);
 FOR mid IN 1..12 LOOP
  INSERT INTO affectation(id,enseignant_id,matiere_id,classe_id,actif) OVERRIDING SYSTEM VALUE VALUES(mid,1,mid,1,true);
  INSERT INTO plan_evaluation(id,affectation_id,version_plan,statut_plan,portee) OVERRIDING SYSTEM VALUE VALUES(mid,mid,1,'BROUILLON','CLASSE');
  FOR j IN 1..3 LOOP
   eid:=(mid-1)*3+j;
   INSERT INTO evaluation(id,affectation_id,type_eval,date_evaluation,mode_evaluation,statut_evaluation,version_calendrier) OVERRIDING SYSTEM VALUE
   VALUES(eid,mid,(ARRAY['CC','TP','SN'])[j],statement_timestamp()-interval '10 days','NORMALE','REALISEE','CAL-1');
   INSERT INTO ligne_plan(plan_id,evaluation_id,retenue,poids_evaluation) VALUES(mid,eid,true,(ARRAY[30,20,50])[j]);
   v:=vals[mid];IF mid=1 THEN v:=(ARRAY[40,50,54.4])[j];END IF;
   INSERT INTO note(evaluation_id,inscription_ue_id,valeur_note,situation,statut_note) VALUES(eid,(mid+1)/2,v,'NUMERIQUE','VALIDEE');
  END LOOP;
  UPDATE plan_evaluation SET statut_plan='ACTIF' WHERE id=mid;
 END LOOP;
END $$;
DO $$ DECLARE t record; mx bigint; BEGIN
 FOR t IN SELECT table_name FROM information_schema.tables WHERE table_schema='gnu' AND table_type='BASE TABLE' LOOP
  EXECUTE format('SELECT max(id) FROM gnu.%I',t.table_name) INTO mx;
  IF mx IS NOT NULL THEN PERFORM setval(pg_get_serial_sequence('gnu.'||t.table_name,'id'),mx); END IF;
 END LOOP;
END $$;
-- Domaines et catalogue
SELECT pg_temp.refuse($q$INSERT INTO ue(code_ue,intitule_ue,niveau_id,version_programme,numero_semestre,categorie_ue,credit_ue,statut_catalogue) VALUES('VIDE','Vide',1,2,1,'FONDAMENTALE',3,'ACTIF')$q$);
SELECT pg_temp.refuse($q$INSERT INTO matiere(code_m,intitule_matiere,ue_id,rang_ec,credit_matiere) VALUES('M13','Troisième EC',1,3,1)$q$);
SELECT pg_temp.refuse($q$UPDATE ue SET credit_ue=100 WHERE id=1$q$);
SELECT pg_temp.refuse($q$UPDATE ligne_plan SET poids_evaluation=10 WHERE plan_id=1$q$);
SELECT pg_temp.refuse($q$SELECT 'NaN'::gnu.note_cent$q$);
SELECT pg_temp.refuse($q$SELECT 'Infinity'::gnu.credit_positif$q$);
SELECT pg_temp.refuse($q$SELECT 101::gnu.note_cent$q$);
SELECT pg_temp.refuse($q$SELECT (-1)::gnu.note_cent$q$);
SELECT exiger(0::note_cent=0,'Zéro est une note valide');
SELECT pg_temp.refuse($q$INSERT INTO plan_evaluation(affectation_id,statut_plan,portee,version_plan) VALUES(1,'ACTIF','CLASSE',2)$q$);
SELECT exiger(nombre_jours_ouvrables('2026-09-04','2026-09-08',ARRAY[]::date[])=2,'Vendredi à mardi : deux jours ouvrables');
SELECT exiger(nombre_jours_ouvrables('2026-09-04','2026-09-08',ARRAY['2026-09-07'::date])=1,'Jour fermé exclu');
SELECT exiger(requete_dans_delai('2026-09-04 14:00+00','2026-09-06 14:00+00'),'48 h exactement recevables');
SELECT exiger(NOT requete_dans_delai('2026-09-04 14:00+00','2026-09-06 14:00:00.000001+00'),'Après 48 h refusé');
SELECT exiger(NOT requete_dans_delai('2026-09-04 14:00+00','2026-09-04 13:59+00'),'Avant publication refusé');
SELECT exiger(rappeler_notes('CAL-1','Africa/Douala')=0,'Notes toutes saisies et validées : aucun rappel');
-- Version et validation d’une note
SELECT set_config('gnu.acteur_id','1',true),set_config('gnu.motif','Correction pour test historique',true);
SELECT pg_temp.refuse($q$UPDATE note SET version_note=999 WHERE evaluation_id=1$q$);
UPDATE note SET valeur_note=40 WHERE evaluation_id=1;
SELECT exiger((SELECT count(*)=2 FROM historique_note WHERE note_id=(SELECT id FROM note WHERE evaluation_id=1)),'Deux versions historisées');
SELECT pg_temp.refuse($q$DELETE FROM historique_note WHERE note_id=1$q$);
SELECT pg_temp.refuse($q$UPDATE note SET valeur_note=101 WHERE evaluation_id=1$q$);
SELECT exiger((calculer_ec(1,1)->>'arrondi')::numeric=50,'49,2 doit être arrondi à 50');
SELECT exiger((calculer_bulletin(1,'ANNUELLE')->>'mgp_total')::numeric=2.4,'MGP normale 2,40');
SELECT exiger(calculer_bulletin(1,'ANNUELLE')->>'decision_admission'='ADMIS','Admission normale');
-- Vérifier les privilèges du rôle serveur non propriétaire.
CREATE ROLE gnu_app_test NOLOGIN;

GRANT USAGE ON SCHEMA gnu TO gnu_app_test;
GRANT USAGE ON TYPE gnu.texte_non_vide, gnu.nombre_fini, gnu.note_cent, gnu.credit_positif, gnu.poids_cent, gnu.mgp_quatre TO gnu_app_test;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA gnu TO gnu_app_test;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA gnu TO gnu_app_test;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA gnu TO gnu_app_test;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON gnu.historique_note, gnu.journal_audit, gnu.publication, gnu.bulletin FROM gnu_app_test;
-- La publication s’effectue uniquement via gnu.publier_classe().
-- Le rôle serveur applicatif est de confiance; il n’est jamais remis aux étudiants.

SET LOCAL ROLE gnu_app_test;
SELECT set_config('gnu.origine','JURY',true),set_config('gnu.reference_jury','PV-DEMO-01',true),set_config('gnu.motif','Décision jury de démonstration',true);
UPDATE note SET valeur_note=40 WHERE evaluation_id=1;
SELECT exiger(EXISTS(SELECT 1 FROM historique_note WHERE origine_modification='JURY' AND reference_jury='PV-DEMO-01'),'Historique jury écrit automatiquement avec droits applicatifs');
SELECT pg_temp.refuse($q$DELETE FROM historique_note WHERE note_id=1$q$,'42501');
SELECT pg_temp.refuse($q$INSERT INTO publication(classe_id,periode,agent_publicateur_id) VALUES(1,'S1',2)$q$,'42501');
RESET ROLE;
SELECT set_config('gnu.origine','',true),set_config('gnu.reference_jury','',true);

-- Seul l’agent publie
SELECT pg_temp.refuse($q$SELECT publier_classe(1,'ANNUELLE')$q$);
SELECT set_config('gnu.acteur_id','2',true);
SET LOCAL ROLE gnu_app_test;
SELECT publier_classe(1,'ANNUELLE');
RESET ROLE;
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
SELECT exiger((SELECT count(DISTINCT matiere_id)=3 FROM liste_rattrapage_sn),'Trois EC éligibles');
SELECT exiger(NOT EXISTS(SELECT 1 FROM liste_rattrapage_sn WHERE matiere_id=1),'EC arrondi 50 exclu');
SELECT pg_temp.refuse($q$UPDATE bulletin SET contenu_fige='{}' WHERE courant$q$);
SELECT set_config('gnu.acteur_id','3',true);
-- Requêtes avec/sans preuve
INSERT INTO requete(inscription_ue_id,matiere_id,bulletin_conteste_id,objet,description,type_requete,statut_requete)
SELECT 1,1,id,'Note','Vérification','CONTESTATION','SOUMISE' FROM bulletin WHERE courant;
DO $$ BEGIN
 BEGIN
  INSERT INTO requete(inscription_ue_id,matiere_id,bulletin_conteste_id,objet,description,type_requete,statut_requete)
  SELECT 1,1,id,'Absence','Preuve manquante','ABSENCE','SOUMISE' FROM bulletin WHERE courant;
  SET CONSTRAINTS ALL IMMEDIATE;
  RAISE EXCEPTION 'Requête sans preuve acceptée';
 EXCEPTION WHEN check_violation THEN NULL; END;
END $$;
-- Préparer les trois rattrapages de SN
SELECT set_config('gnu.acteur_id','1',true),set_config('gnu.motif','Organisation du rattrapage',true);
DO $$ DECLARE r record; ev bigint; cid bigint; BEGIN
 FOR r IN SELECT * FROM liste_rattrapage_sn ORDER BY matiere_id LOOP
  INSERT INTO evaluation(affectation_id,type_eval,date_evaluation,mode_evaluation,statut_evaluation,evaluation_origine_id,version_calendrier)
  VALUES(r.matiere_id,'SN',statement_timestamp(),'RATTRAPAGE','REALISEE',r.evaluation_origine_id,'CAL-1') RETURNING id INTO ev;
  INSERT INTO candidature_rattrapage(inscription_ue_id,matiere_id,bulletin_source_id,evaluation_origine_id,evaluation_rattrapage_id,statut_candidature)
  VALUES(r.inscription_ue_id,r.matiere_id,r.bulletin_source_id,r.evaluation_origine_id,ev,'PROGRAMMEE') RETURNING id INTO cid;
 END LOOP;
END $$;
SAVEPOINT alternatives;
-- A : nouvelles SN 70,60,56 -> MGP 2,61
DO $$ DECLARE c candidature_rattrapage; BEGIN
 PERFORM set_config('gnu.motif','Note de rattrapage',true);
 FOR c IN SELECT * FROM candidature_rattrapage LOOP
  INSERT INTO note(evaluation_id,inscription_ue_id,valeur_note,situation,statut_note)
  VALUES(c.evaluation_rattrapage_id,c.inscription_ue_id,CASE c.matiere_id WHEN 3 THEN 70 WHEN 5 THEN 60 WHEN 6 THEN 56 END,'NUMERIQUE','VALIDEE');
 END LOOP;
END $$;
SELECT exiger((calculer_bulletin(1,'ANNUELLE')->>'mgp_total')::numeric=2.61,'Après rattrapage : MGP 2,61');
SELECT pg_temp.refuse($q$UPDATE candidature_rattrapage SET date_consommation=NULL,statut_candidature='PROGRAMMEE' WHERE matiere_id=3$q$);
SELECT pg_temp.refuse($q$INSERT INTO candidature_rattrapage(inscription_ue_id,matiere_id,bulletin_source_id,evaluation_origine_id,statut_candidature) SELECT inscription_ue_id,matiere_id,bulletin_source_id,evaluation_origine_id,'ELIGIBLE' FROM candidature_rattrapage WHERE matiere_id=3$q$,'23505');
SELECT set_config('gnu.acteur_id','2',true);
SET LOCAL ROLE gnu_app_test;
SELECT publier_classe(1,'ANNUELLE');
RESET ROLE;
SELECT exiger((SELECT count(*)=2 FROM bulletin),'Ancien bulletin préservé');
SELECT set_config('gnu.acteur_id','3',true);
-- Une republication ne rouvre pas le délai sur un EC inchangé.
SELECT pg_temp.refuse($q$INSERT INTO requete(inscription_ue_id,matiere_id,bulletin_conteste_id,objet,description,type_requete,statut_requete) SELECT 1,1,id,'Note','Inchangée','CONTESTATION','SOUMISE' FROM bulletin WHERE courant$q$);
INSERT INTO requete(inscription_ue_id,matiere_id,bulletin_conteste_id,objet,description,type_requete,statut_requete)
SELECT 2,3,id,'Note','Corrigée','CONTESTATION','SOUMISE' FROM bulletin WHERE courant;
SET CONSTRAINTS ALL IMMEDIATE;
ROLLBACK TO SAVEPOINT alternatives;
-- B : absence à SN, EL conservé, MGP > 2 mais échec
SELECT set_config('gnu.acteur_id','1',true),set_config('gnu.motif','Absence au rattrapage constatée',true);
INSERT INTO note(evaluation_id,inscription_ue_id,situation,statut_note)
SELECT evaluation_rattrapage_id,inscription_ue_id,'ABSENTE','VALIDEE' FROM candidature_rattrapage WHERE matiere_id=3;
SELECT exiger(calculer_bulletin(1,'ANNUELLE')->>'decision_admission'='ECHEC','EL bloque admission');
SELECT exiger(round((calculer_bulletin(1,'ANNUELLE')->>'mgp_total')::numeric,2)=2.13,'EL garde ses crédits au dénominateur');
SELECT exiger(calculer_ue(2)->>'grade'='EL' AND calculer_ue(2)->>'arrondi' IS NULL,'EL affiché sans note zéro');
SELECT set_config('gnu.acteur_id','2',true);
SET LOCAL ROLE gnu_app_test;
SELECT publier_classe(1,'ANNUELLE');
RESET ROLE;
-- Reprise de tous les EC d’une UE EL l’année suivante
INSERT INTO inscription_classe(id,etudiant_id,classe_id,statut_redoublant,statut_inscription) OVERRIDING SYSTEM VALUE VALUES(2,1,2,true,'VALIDEE');
INSERT INTO inscription_ue(inscription_classe_id,ue_id,type_inscription,statut_inscription,bulletin_source_id,ue_source_id)
SELECT 2,2,'REPRISE','VALIDEE',id,2 FROM bulletin WHERE courant;
SELECT pg_temp.refuse($q$INSERT INTO inscription_ue(inscription_classe_id,ue_id,type_inscription,statut_inscription,bulletin_source_id,ue_source_id) SELECT 2,3,'CONSERVEE','VALIDEE',id,3 FROM bulletin WHERE courant$q$);
INSERT INTO inscription_ue(inscription_classe_id,ue_id,type_inscription,statut_inscription,bulletin_source_id,ue_source_id)
SELECT 2,1,'CONSERVEE','VALIDEE',id,1 FROM bulletin WHERE courant;
SELECT exiger((SELECT type_inscription='REPRISE' FROM inscription_ue WHERE inscription_classe_id=2 AND ue_id=2),'Tous les EC de UE2 relèvent de la reprise');
SET CONSTRAINTS ALL IMMEDIATE;
ROLLBACK TO SAVEPOINT alternatives;
-- C : une SN plus basse remplace définitivement l’ancienne
SELECT set_config('gnu.acteur_id','1',true),set_config('gnu.motif','Rattrapage plus bas',true);
INSERT INTO note(evaluation_id,inscription_ue_id,valeur_note,situation,statut_note)
SELECT evaluation_rattrapage_id,inscription_ue_id,20,'NUMERIQUE','VALIDEE' FROM candidature_rattrapage WHERE matiere_id=3;
SELECT exiger((calculer_ec(2,3)->>'arrondi')::numeric=27,'La SN de 20 remplace 34');
SELECT exiger((calculer_ue(2)->>'arrondi')::numeric=49,'UE arrondie après SN plus basse');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT 'Tous les scénarios SQL ont réussi; annulation des données de test.' AS resultat;
ROLLBACK;
