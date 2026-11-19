CREATE SCHEMA gnu;
CREATE TABLE gnu.universite (id int, nom_univ text);
CREATE TABLE gnu.faculte (id int, universite_id int, nom_fac text);
CREATE TABLE gnu.departement (id int, faculte_id int, nom_depart text);
CREATE TABLE gnu.filiere (id int, departement_id int, nom_f text);
CREATE TABLE gnu.specialite (id int, libelle_specialite text);
CREATE TABLE gnu.niveau (id int, filiere_id int, specialite_id int, code_niv text, libelle_niv text);
CREATE TABLE gnu.annee_academique (id int, libelle text, date_debut date);
CREATE TABLE gnu.classe (id int, code_classe text, niveau_id int, annee_id int);
CREATE TABLE gnu.etudiant (id int, utilisateur_id int, matricule text, date_naissance date, lieu_naissance text);
CREATE TABLE gnu.inscription_classe (id int, classe_id int, etudiant_id int, statut_inscription text, statut_redoublant boolean);
CREATE TABLE gnu.ue (id int, intitule_ue text);
CREATE TABLE gnu.logo_structure (departement_id int, faculte_id int, universite_id int, chemin_fichier text, type_mime text);
CREATE TABLE gnu.publication (id int, classe_id int, periode text, date_publication date);
CREATE TABLE gnu.bulletin (id int, inscription_classe_id int, publication_id int, periode text, courant boolean,
    version_bulletin int, mgp_s1 numeric, mgp_s2 numeric, mgp_total numeric, total_credits numeric, decision_admission text, contenu_fige jsonb);
CREATE TABLE gnu.document_bulletin (id serial, bulletin_id int unique, reference_officielle text unique, chemin_fichier text,
    empreinte_sha256 text, genere_par int, date_emission timestamp, created_at timestamp, updated_at timestamp);
INSERT INTO gnu.universite VALUES (1,'Université de Yaoundé I');
INSERT INTO gnu.faculte VALUES (1,1,'Faculté des sciences');
INSERT INTO gnu.departement VALUES (1,1,'Informatique');
INSERT INTO gnu.filiere VALUES (1,1,'Informatique');
INSERT INTO gnu.niveau VALUES (1,1,null,'L2','Licence 2');
INSERT INTO gnu.annee_academique VALUES (1,'2025-2026','2025-09-01');
INSERT INTO gnu.classe VALUES (1,'INF-L2',1,1);
INSERT INTO gnu.etudiant VALUES (1,1,'DEMO-A',null,null),(2,2,'DEMO-B',null,null);
INSERT INTO gnu.inscription_classe VALUES (1,1,1,'VALIDEE',false),(2,1,2,'VALIDEE',false);
INSERT INTO gnu.ue VALUES (1,'Informatique');
INSERT INTO gnu.publication VALUES (1,1,'S2','2026-06-01');
