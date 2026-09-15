SET search_path TO gnu, public;

INSERT INTO universite(code_univ,nom_univ) VALUES ('UY1','Université de Yaoundé I');
INSERT INTO faculte(code_fac,nom_fac,universite_id) SELECT 'FS','Faculté des Sciences',(SELECT id FROM universite WHERE code_univ='UY1');
INSERT INTO departement(code_de,nom_depart,faculte_id) SELECT 'INFO','Département d''Informatique',(SELECT id FROM faculte WHERE code_fac='FS');
INSERT INTO filiere(code_f,nom_f,departement_id) SELECT 'GL','Génie logiciel',(SELECT id FROM departement WHERE code_de='INFO');
INSERT INTO niveau(code_niv,cycle_niv,libelle_niv,filiere_id) SELECT 'L3','LICENCE','Licence 3',(SELECT id FROM filiere WHERE code_f='GL');
INSERT INTO annee_academique(libelle,date_debut,date_fin) VALUES ('2025-2026','2025-10-01','2026-07-31');
INSERT INTO classe(code_classe,niveau_id,annee_id,version_programme) SELECT 'L3-GL-A',n.id,a.id,1 FROM niveau n,annee_academique a WHERE n.code_niv='L3' AND a.libelle='2025-2026';

INSERT INTO ue(code_ue,intitule_ue,niveau_id,version_programme,numero_semestre,categorie_ue,credit_ue,statut_catalogue) SELECT 'INF331','Développement logiciel',id,1,1,'FONDAMENTALE',6,'ACTIF' FROM niveau WHERE code_niv='L3';
INSERT INTO matiere(code_m,intitule_matiere,ue_id,rang_ec,credit_matiere) SELECT 'INF331-EC1','Projet logiciel',id,1,6 FROM ue WHERE code_ue='INF331';

INSERT INTO utilisateur(code_utilisateur,login,mot_de_passe_hash,role,nom,prenom) VALUES
 ('AG001','agent','demo','AGENT','Messi','Agent'), ('EN001','enseignant','demo','ENSEIGNANT','Kouam','Jean'), ('ET001','etudiant','demo','ETUDIANT','Ngue Mbong','André Fitzgerald');
INSERT INTO enseignant(eid,utilisateur_id,fonction_enseignant) SELECT 'EN001',id,'Chargé de cours' FROM utilisateur WHERE code_utilisateur='EN001';
INSERT INTO etudiant(matricule,utilisateur_id) SELECT '21T2355',id FROM utilisateur WHERE code_utilisateur='ET001';
INSERT INTO inscription_classe(etudiant_id,classe_id,statut_inscription) SELECT e.id,c.id,'VALIDEE' FROM etudiant e,classe c WHERE e.matricule='21T2355' AND c.code_classe='L3-GL-A';
INSERT INTO inscription_ue(inscription_classe_id,ue_id,type_inscription,statut_inscription) SELECT ic.id,u.id,'NORMALE','VALIDEE' FROM inscription_classe ic,ue u WHERE u.code_ue='INF331';
INSERT INTO affectation(enseignant_id,matiere_id,classe_id) SELECT en.id,m.id,c.id FROM enseignant en,matiere m,classe c WHERE en.eid='EN001' AND m.code_m='INF331-EC1' AND c.code_classe='L3-GL-A';
INSERT INTO evaluation(affectation_id,type_eval,date_evaluation,mode_evaluation,statut_evaluation,version_calendrier) SELECT id,'SN',statement_timestamp(),'NORMALE','REALISEE','V1' FROM affectation;
INSERT INTO plan_evaluation(affectation_id,version_plan,statut_plan,portee) SELECT id,1,'ACTIF','CLASSE' FROM affectation;
INSERT INTO ligne_plan(plan_id,evaluation_id,retenue,poids_evaluation) SELECT p.id,e.id,true,100 FROM plan_evaluation p,evaluation e;
SELECT set_config('gnu.acteur_id', (SELECT id::text FROM utilisateur WHERE role='ENSEIGNANT'), false);
SELECT set_config('gnu.motif', 'Jeu de données initial de démonstration', false);
SELECT set_config('gnu.origine', 'UTILISATEUR', false);
INSERT INTO note(evaluation_id,inscription_ue_id,valeur_note,situation,statut_note,validateur_id,date_validation) SELECT e.id,iu.id,76,'NUMERIQUE','VALIDEE',u.id,statement_timestamp() FROM evaluation e,inscription_ue iu,utilisateur u WHERE u.role='ENSEIGNANT';
