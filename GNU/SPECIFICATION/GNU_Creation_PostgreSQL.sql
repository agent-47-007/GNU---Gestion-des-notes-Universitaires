-- GNU PostgreSQL 1.0 / 29 tables métier / PostgreSQL 14+
-- Installation initiale atomique. Refuse un schéma gnu préexistant.
-- Exécuter avec psql -X -v ON_ERROR_STOP=1 -f 001_creation.sql
BEGIN;
CREATE SCHEMA gnu;
REVOKE ALL ON SCHEMA gnu FROM PUBLIC;
SET LOCAL search_path = gnu, pg_catalog;
CREATE DOMAIN texte_non_vide AS text CHECK (btrim(VALUE) <> '');
CREATE DOMAIN nombre_fini AS numeric CHECK (VALUE NOT IN ('NaN'::numeric,'Infinity'::numeric,'-Infinity'::numeric));
CREATE DOMAIN note_cent AS nombre_fini CHECK (VALUE BETWEEN 0 AND 100);
CREATE DOMAIN credit_positif AS nombre_fini CHECK (VALUE > 0);
CREATE DOMAIN poids_cent AS nombre_fini CHECK (VALUE BETWEEN 0 AND 100);
CREATE DOMAIN mgp_quatre AS nombre_fini CHECK (VALUE BETWEEN 0 AND 4);


-- Code_Univ
CREATE TABLE universite (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  code_univ texte_non_vide NOT NULL,
  nom_univ texte_non_vide NOT NULL,
  created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  UNIQUE (code_univ)
);

-- Code_Fac
CREATE TABLE faculte (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  code_fac texte_non_vide NOT NULL,
  nom_fac texte_non_vide NOT NULL,
  universite_id bigint NOT NULL,
  created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  UNIQUE (universite_id,code_fac)
);

-- Code_De
CREATE TABLE departement (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  code_de texte_non_vide NOT NULL,
  nom_depart texte_non_vide NOT NULL,
  faculte_id bigint NOT NULL,
  created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  UNIQUE (faculte_id,code_de)
);

-- Code_F
CREATE TABLE filiere (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  code_f texte_non_vide NOT NULL,
  nom_f texte_non_vide NOT NULL,
  departement_id bigint NOT NULL,
  created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  UNIQUE (departement_id,code_f)
);

-- Code_Niv
CREATE TABLE niveau (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  code_niv texte_non_vide NOT NULL,
  cycle_niv texte_non_vide NOT NULL,
  libelle_niv texte_non_vide NOT NULL,
  filiere_id bigint NOT NULL,
  created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  UNIQUE (filiere_id,code_niv)
);

-- Annee_Academique
CREATE TABLE annee_academique (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  libelle texte_non_vide NOT NULL,
  date_debut date NOT NULL,
  date_fin date NOT NULL,
  created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  UNIQUE (libelle),
  CHECK (date_fin > date_debut)
);

-- Code_Classe
CREATE TABLE classe (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  code_classe texte_non_vide NOT NULL,
  niveau_id bigint NOT NULL,
  annee_id bigint NOT NULL,
  version_programme integer NOT NULL,
  created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  UNIQUE (code_classe),
  UNIQUE (niveau_id,annee_id),
  CHECK (version_programme>0)
);

-- Code_UE
CREATE TABLE ue (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  code_ue texte_non_vide NOT NULL,
  intitule_ue texte_non_vide NOT NULL,
  niveau_id bigint NOT NULL,
  version_programme integer NOT NULL,
  numero_semestre smallint NOT NULL,
  categorie_ue texte_non_vide NOT NULL,
  credit_ue credit_positif NOT NULL,
  statut_catalogue texte_non_vide NOT NULL,
  created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  UNIQUE (niveau_id,version_programme,code_ue),
  CHECK (version_programme>0),
  CHECK (categorie_ue IN ('FONDAMENTALE','OPTIONNELLE')),
  CHECK (statut_catalogue IN ('BROUILLON','ACTIF','ARCHIVE')),
  CHECK (numero_semestre IN (1,2))
);

-- Code_M
CREATE TABLE matiere (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  code_m texte_non_vide NOT NULL,
  intitule_matiere texte_non_vide NOT NULL,
  ue_id bigint NOT NULL,
  rang_ec smallint NOT NULL,
  credit_matiere credit_positif NOT NULL,
  created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  UNIQUE (ue_id,code_m),
  UNIQUE (ue_id,rang_ec),
  CHECK (rang_ec IN (1,2))
);

-- Code_Utilisateur
CREATE TABLE utilisateur (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  code_utilisateur texte_non_vide NOT NULL,
  login texte_non_vide NOT NULL,
  mot_de_passe_hash texte_non_vide NOT NULL,
  role texte_non_vide NOT NULL,
  actif boolean NOT NULL DEFAULT true,
  nom texte_non_vide NOT NULL,
  prenom texte_non_vide,
  created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  UNIQUE (code_utilisateur),
  CHECK (role IN ('ETUDIANT','ENSEIGNANT','AGENT'))
);

-- Matricule
CREATE TABLE etudiant (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  matricule texte_non_vide NOT NULL,
  utilisateur_id bigint NOT NULL,
  created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  UNIQUE (matricule),
  UNIQUE (utilisateur_id)
);

-- EID
CREATE TABLE enseignant (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  eid texte_non_vide NOT NULL,
  utilisateur_id bigint NOT NULL,
  fonction_enseignant texte_non_vide,
  created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  UNIQUE (eid),
  UNIQUE (utilisateur_id)
);

-- Code_Inscription_Classe
CREATE TABLE inscription_classe (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  etudiant_id bigint NOT NULL,
  classe_id bigint NOT NULL,
  statut_redoublant boolean NOT NULL DEFAULT false,
  statut_inscription texte_non_vide NOT NULL,
  created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  UNIQUE (etudiant_id,classe_id),
  CHECK (statut_inscription IN ('BROUILLON','VALIDEE','ANNULEE'))
);

-- Code_Inscription_UE
CREATE TABLE inscription_ue (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  inscription_classe_id bigint NOT NULL,
  ue_id bigint NOT NULL,
  type_inscription texte_non_vide NOT NULL,
  statut_inscription texte_non_vide NOT NULL,
  bulletin_source_id bigint,
  ue_source_id bigint,
  created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  UNIQUE (inscription_classe_id,ue_id),
  CHECK (type_inscription IN ('NORMALE','REPRISE','CONSERVEE')),
  CHECK (statut_inscription IN ('BROUILLON','VALIDEE','ANNULEE')),
  CHECK ((type_inscription='NORMALE' AND bulletin_source_id IS NULL AND ue_source_id IS NULL) OR (type_inscription IN ('REPRISE','CONSERVEE') AND bulletin_source_id IS NOT NULL AND ue_source_id IS NOT NULL))
);

-- Code_Affectation
CREATE TABLE affectation (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  enseignant_id bigint NOT NULL,
  matiere_id bigint NOT NULL,
  classe_id bigint NOT NULL,
  actif boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT statement_timestamp()
);

-- Code_Evaluation
CREATE TABLE evaluation (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  affectation_id bigint NOT NULL,
  type_eval texte_non_vide NOT NULL,
  date_evaluation timestamptz NOT NULL,
  mode_evaluation texte_non_vide NOT NULL,
  statut_evaluation texte_non_vide NOT NULL,
  evaluation_origine_id bigint,
  version_calendrier texte_non_vide NOT NULL,
  created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  CHECK (type_eval IN ('CC','TP','SN')),
  CHECK (mode_evaluation IN ('NORMALE','RATTRAPAGE')),
  CHECK (statut_evaluation IN ('BROUILLON','PROGRAMMEE','REALISEE','ANNULEE')),
  CHECK ((mode_evaluation='NORMALE' AND evaluation_origine_id IS NULL) OR (mode_evaluation='RATTRAPAGE' AND evaluation_origine_id IS NOT NULL AND evaluation_origine_id <> id))
);

-- Code_Plan
CREATE TABLE plan_evaluation (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  affectation_id bigint NOT NULL,
  version_plan integer NOT NULL DEFAULT 1,
  statut_plan texte_non_vide NOT NULL,
  portee texte_non_vide NOT NULL,
  inscription_ue_id bigint,
  decision_id bigint,
  plan_commun_id bigint,
  created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  CHECK (version_plan>0),
  CHECK (statut_plan IN ('BROUILLON','ACTIF','ARCHIVE')),
  CHECK (portee IN ('CLASSE','ETUDIANT')),
  CHECK ((portee='CLASSE' AND inscription_ue_id IS NULL AND decision_id IS NULL AND plan_commun_id IS NULL) OR (portee='ETUDIANT' AND inscription_ue_id IS NOT NULL AND decision_id IS NOT NULL AND plan_commun_id IS NOT NULL AND plan_commun_id<>id))
);

-- Code_Ligne_Plan
CREATE TABLE ligne_plan (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  plan_id bigint NOT NULL,
  evaluation_id bigint NOT NULL,
  retenue boolean NOT NULL,
  poids_evaluation poids_cent NOT NULL,
  created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  UNIQUE (plan_id,evaluation_id),
  CHECK ((retenue AND poids_evaluation>0) OR (NOT retenue AND poids_evaluation=0))
);

-- Code_Note
CREATE TABLE note (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  evaluation_id bigint NOT NULL,
  inscription_ue_id bigint NOT NULL,
  valeur_note note_cent,
  situation texte_non_vide NOT NULL,
  statut_note texte_non_vide NOT NULL,
  version_note integer NOT NULL DEFAULT 1,
  validateur_id bigint,
  date_validation timestamptz,
  created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  UNIQUE (evaluation_id,inscription_ue_id),
  CHECK (version_note>0),
  CHECK (situation IN ('NUMERIQUE','ABSENTE','MANQUANTE')),
  CHECK (statut_note IN ('BROUILLON','VALIDEE')),
  CHECK ((situation='NUMERIQUE' AND valeur_note IS NOT NULL) OR (situation IN ('ABSENTE','MANQUANTE') AND valeur_note IS NULL)),
  CHECK ((statut_note='BROUILLON' AND validateur_id IS NULL AND date_validation IS NULL) OR (statut_note='VALIDEE' AND validateur_id IS NOT NULL AND date_validation IS NOT NULL AND situation<>'MANQUANTE'))
);

-- Code_Historique_Note
CREATE TABLE historique_note (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  note_id bigint NOT NULL,
  version_note integer NOT NULL DEFAULT 1,
  auteur_id bigint NOT NULL,
  date_modification timestamptz NOT NULL DEFAULT statement_timestamp(),
  motif texte_non_vide NOT NULL,
  origine_modification texte_non_vide NOT NULL,
  decision_id bigint,
  reference_jury texte_non_vide,
  avant jsonb,
  apres jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  UNIQUE (note_id,version_note),
  CHECK (version_note>0),
  CHECK (jsonb_typeof(avant)='object'),
  CHECK (jsonb_typeof(apres)='object'),
  CHECK (origine_modification IN ('SAISIE','CORRECTION','RATTRAPAGE','REQUETE','JURY','VALIDATION')),
  CHECK (origine_modification <> 'JURY' OR reference_jury IS NOT NULL)
);

-- Code_Re
CREATE TABLE requete (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  inscription_ue_id bigint NOT NULL,
  matiere_id bigint NOT NULL,
  evaluation_id bigint,
  note_id bigint,
  bulletin_conteste_id bigint NOT NULL,
  objet texte_non_vide NOT NULL,
  description texte_non_vide NOT NULL,
  type_requete texte_non_vide NOT NULL,
  statut_requete texte_non_vide NOT NULL,
  date_soumission timestamptz NOT NULL DEFAULT statement_timestamp(),
  created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  CHECK (type_requete IN ('ABSENCE','CONTESTATION','NOTE_MANQUANTE','REEVALUATION')),
  CHECK (statut_requete IN ('SOUMISE','EN_TRAITEMENT','DECIDEE'))
);

-- Code_Justificatif
CREATE TABLE justificatif (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  requete_id bigint NOT NULL,
  reference_fichier_prive texte_non_vide NOT NULL,
  type_fichier texte_non_vide NOT NULL,
  taille_octets bigint NOT NULL,
  empreinte texte_non_vide NOT NULL,
  date_depot timestamptz NOT NULL DEFAULT statement_timestamp(),
  created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  CHECK (taille_octets>0)
);

-- Code_Decision
CREATE TABLE decision_requete (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  requete_id bigint NOT NULL,
  enseignant_id bigint NOT NULL,
  version_decision integer NOT NULL DEFAULT 1,
  action_decision texte_non_vide NOT NULL,
  motif texte_non_vide NOT NULL,
  date_decision timestamptz NOT NULL DEFAULT statement_timestamp(),
  courante boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  UNIQUE (requete_id,version_decision),
  CHECK (version_decision>0),
  CHECK (action_decision IN ('AUTORISER_EVALUATION','ATTRIBUER_ZERO','CORRIGER_NOTE','REJETER'))
);

-- Code_Session
CREATE TABLE session_rattrapage (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  classe_id bigint NOT NULL,
  libelle texte_non_vide NOT NULL,
  date_session date NOT NULL,
  statut_session texte_non_vide NOT NULL,
  created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  CHECK (statut_session IN ('PREVUE','OUVERTE','CLOTUREE','ANNULEE'))
);

-- Code_Candidature
CREATE TABLE candidature_rattrapage (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  session_id bigint,
  inscription_ue_id bigint NOT NULL,
  matiere_id bigint NOT NULL,
  etudiant_id bigint NOT NULL,
  annee_id bigint NOT NULL,
  niveau_id bigint NOT NULL,
  code_m_scope texte_non_vide NOT NULL,
  bulletin_source_id bigint NOT NULL,
  evaluation_origine_id bigint NOT NULL,
  evaluation_rattrapage_id bigint,
  autorisation_id bigint,
  statut_candidature texte_non_vide NOT NULL,
  date_consommation timestamptz,
  created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  UNIQUE (etudiant_id,annee_id,niveau_id,code_m_scope),
  CHECK (statut_candidature IN ('ELIGIBLE','AUTORISEE','PROGRAMMEE','COMPOSEE','ABSENTE','ANNULEE')),
  CHECK (statut_candidature NOT IN ('COMPOSEE','ABSENTE') OR (date_consommation IS NOT NULL AND evaluation_rattrapage_id IS NOT NULL)),
  CHECK (date_consommation IS NULL OR statut_candidature IN ('COMPOSEE','ABSENTE'))
);

-- Code_Publication
CREATE TABLE publication (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  classe_id bigint NOT NULL,
  periode texte_non_vide NOT NULL,
  version_publication integer NOT NULL DEFAULT 1,
  date_publication timestamptz NOT NULL DEFAULT statement_timestamp(),
  agent_publicateur_id bigint NOT NULL,
  publication_precedente_id bigint,
  created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  UNIQUE (classe_id,periode,version_publication),
  CHECK (version_publication>0),
  CHECK (periode IN ('S1','S2','ANNUELLE'))
);

-- Code_Bulletin
CREATE TABLE bulletin (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  publication_id bigint NOT NULL,
  inscription_classe_id bigint NOT NULL,
  periode texte_non_vide NOT NULL,
  version_bulletin integer NOT NULL DEFAULT 1,
  courant boolean NOT NULL DEFAULT true,
  mgp_s1 mgp_quatre,
  mgp_s2 mgp_quatre,
  mgp_total mgp_quatre,
  somme_points_credits nombre_fini NOT NULL,
  total_credits credit_positif NOT NULL,
  decision_admission texte_non_vide NOT NULL,
  contenu_fige jsonb NOT NULL,
  version_schema_contenu integer NOT NULL DEFAULT 1,
  version_regles texte_non_vide NOT NULL,
  version_bareme texte_non_vide NOT NULL,
  created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  UNIQUE (publication_id,inscription_classe_id),
  UNIQUE (inscription_classe_id,periode,version_bulletin),
  CHECK (version_bulletin>0),
  CHECK (jsonb_typeof(contenu_fige)='object'),
  CHECK (version_schema_contenu>0),
  CHECK (periode IN ('S1','S2','ANNUELLE')),
  CHECK (decision_admission IN ('ADMIS','ECHEC','NON_APPLICABLE'))
);

-- Code_Notification
CREATE TABLE notification (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  destinataire_id bigint NOT NULL,
  evaluation_id bigint,
  requete_id bigint,
  type_notification texte_non_vide NOT NULL,
  cle_evenement texte_non_vide NOT NULL,
  contenu jsonb NOT NULL,
  jour_ouvrable date,
  date_envoi timestamptz,
  date_lecture timestamptz,
  statut_envoi texte_non_vide NOT NULL,
  created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  UNIQUE (destinataire_id,cle_evenement),
  CHECK (jsonb_typeof(contenu)='object'),
  CHECK (type_notification IN ('RAPPEL_NOTES','REQUETE_DEPOSEE','REQUETE_DECIDEE','PUBLICATION')),
  CHECK (statut_envoi IN ('EN_ATTENTE','ENVOYEE','ECHEC')),
  CHECK (type_notification <> 'RAPPEL_NOTES' OR (evaluation_id IS NOT NULL AND jour_ouvrable IS NOT NULL))
);

-- Code_Audit
CREATE TABLE journal_audit (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  acteur_id bigint,
  origine texte_non_vide NOT NULL,
  action texte_non_vide NOT NULL,
  date_action timestamptz NOT NULL DEFAULT statement_timestamp(),
  type_objet texte_non_vide NOT NULL,
  identifiant_objet texte_non_vide NOT NULL,
  avant jsonb,
  apres jsonb,
  motif texte_non_vide NOT NULL,
  created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  CHECK (jsonb_typeof(avant)='object'),
  CHECK (jsonb_typeof(apres)='object'),
  CHECK (origine IN ('UTILISATEUR','SYSTEME')),
  CHECK ((origine='SYSTEME' AND acteur_id IS NULL) OR (origine='UTILISATEUR' AND acteur_id IS NOT NULL))
);

ALTER TABLE faculte ADD CONSTRAINT fk_faculte_universite_id FOREIGN KEY (universite_id) REFERENCES universite(id) ON DELETE RESTRICT;

ALTER TABLE departement ADD CONSTRAINT fk_departement_faculte_id FOREIGN KEY (faculte_id) REFERENCES faculte(id) ON DELETE RESTRICT;

ALTER TABLE filiere ADD CONSTRAINT fk_filiere_departement_id FOREIGN KEY (departement_id) REFERENCES departement(id) ON DELETE RESTRICT;

ALTER TABLE niveau ADD CONSTRAINT fk_niveau_filiere_id FOREIGN KEY (filiere_id) REFERENCES filiere(id) ON DELETE RESTRICT;

ALTER TABLE classe ADD CONSTRAINT fk_classe_niveau_id FOREIGN KEY (niveau_id) REFERENCES niveau(id) ON DELETE RESTRICT;

ALTER TABLE classe ADD CONSTRAINT fk_classe_annee_id FOREIGN KEY (annee_id) REFERENCES annee_academique(id) ON DELETE RESTRICT;

CREATE INDEX ix_classe_annee_id ON classe(annee_id);

ALTER TABLE ue ADD CONSTRAINT fk_ue_niveau_id FOREIGN KEY (niveau_id) REFERENCES niveau(id) ON DELETE RESTRICT;

ALTER TABLE matiere ADD CONSTRAINT fk_matiere_ue_id FOREIGN KEY (ue_id) REFERENCES ue(id) ON DELETE RESTRICT;

ALTER TABLE etudiant ADD CONSTRAINT fk_etudiant_utilisateur_id FOREIGN KEY (utilisateur_id) REFERENCES utilisateur(id) ON DELETE RESTRICT;

ALTER TABLE enseignant ADD CONSTRAINT fk_enseignant_utilisateur_id FOREIGN KEY (utilisateur_id) REFERENCES utilisateur(id) ON DELETE RESTRICT;

ALTER TABLE inscription_classe ADD CONSTRAINT fk_inscription_classe_etudiant_id FOREIGN KEY (etudiant_id) REFERENCES etudiant(id) ON DELETE RESTRICT;

ALTER TABLE inscription_classe ADD CONSTRAINT fk_inscription_classe_classe_id FOREIGN KEY (classe_id) REFERENCES classe(id) ON DELETE RESTRICT;

CREATE INDEX ix_inscription_classe_classe_id ON inscription_classe(classe_id);

ALTER TABLE inscription_ue ADD CONSTRAINT fk_inscription_ue_inscription_classe_id FOREIGN KEY (inscription_classe_id) REFERENCES inscription_classe(id) ON DELETE RESTRICT;

ALTER TABLE inscription_ue ADD CONSTRAINT fk_inscription_ue_ue_id FOREIGN KEY (ue_id) REFERENCES ue(id) ON DELETE RESTRICT;

CREATE INDEX ix_inscription_ue_ue_id ON inscription_ue(ue_id);

ALTER TABLE inscription_ue ADD CONSTRAINT fk_inscription_ue_bulletin_source_id FOREIGN KEY (bulletin_source_id) REFERENCES bulletin(id) ON DELETE RESTRICT;

CREATE INDEX ix_inscription_ue_bulletin_source_id ON inscription_ue(bulletin_source_id);

ALTER TABLE inscription_ue ADD CONSTRAINT fk_inscription_ue_ue_source_id FOREIGN KEY (ue_source_id) REFERENCES ue(id) ON DELETE RESTRICT;

CREATE INDEX ix_inscription_ue_ue_source_id ON inscription_ue(ue_source_id);

ALTER TABLE affectation ADD CONSTRAINT fk_affectation_enseignant_id FOREIGN KEY (enseignant_id) REFERENCES enseignant(id) ON DELETE RESTRICT;

CREATE INDEX ix_affectation_enseignant_id ON affectation(enseignant_id);

ALTER TABLE affectation ADD CONSTRAINT fk_affectation_matiere_id FOREIGN KEY (matiere_id) REFERENCES matiere(id) ON DELETE RESTRICT;

CREATE INDEX ix_affectation_matiere_id ON affectation(matiere_id);

ALTER TABLE affectation ADD CONSTRAINT fk_affectation_classe_id FOREIGN KEY (classe_id) REFERENCES classe(id) ON DELETE RESTRICT;

CREATE INDEX ix_affectation_classe_id ON affectation(classe_id);

ALTER TABLE evaluation ADD CONSTRAINT fk_evaluation_affectation_id FOREIGN KEY (affectation_id) REFERENCES affectation(id) ON DELETE RESTRICT;

CREATE INDEX ix_evaluation_affectation_id ON evaluation(affectation_id);

ALTER TABLE evaluation ADD CONSTRAINT fk_evaluation_evaluation_origine_id FOREIGN KEY (evaluation_origine_id) REFERENCES evaluation(id) ON DELETE RESTRICT;

CREATE INDEX ix_evaluation_evaluation_origine_id ON evaluation(evaluation_origine_id);

ALTER TABLE plan_evaluation ADD CONSTRAINT fk_plan_evaluation_affectation_id FOREIGN KEY (affectation_id) REFERENCES affectation(id) ON DELETE RESTRICT;

CREATE INDEX ix_plan_evaluation_affectation_id ON plan_evaluation(affectation_id);

ALTER TABLE plan_evaluation ADD CONSTRAINT fk_plan_evaluation_inscription_ue_id FOREIGN KEY (inscription_ue_id) REFERENCES inscription_ue(id) ON DELETE RESTRICT;

CREATE INDEX ix_plan_evaluation_inscription_ue_id ON plan_evaluation(inscription_ue_id);

ALTER TABLE plan_evaluation ADD CONSTRAINT fk_plan_evaluation_decision_id FOREIGN KEY (decision_id) REFERENCES decision_requete(id) ON DELETE RESTRICT;

CREATE INDEX ix_plan_evaluation_decision_id ON plan_evaluation(decision_id);

ALTER TABLE plan_evaluation ADD CONSTRAINT fk_plan_evaluation_plan_commun_id FOREIGN KEY (plan_commun_id) REFERENCES plan_evaluation(id) ON DELETE RESTRICT;

CREATE INDEX ix_plan_evaluation_plan_commun_id ON plan_evaluation(plan_commun_id);

ALTER TABLE ligne_plan ADD CONSTRAINT fk_ligne_plan_plan_id FOREIGN KEY (plan_id) REFERENCES plan_evaluation(id) ON DELETE RESTRICT;

ALTER TABLE ligne_plan ADD CONSTRAINT fk_ligne_plan_evaluation_id FOREIGN KEY (evaluation_id) REFERENCES evaluation(id) ON DELETE RESTRICT;

CREATE INDEX ix_ligne_plan_evaluation_id ON ligne_plan(evaluation_id);

ALTER TABLE note ADD CONSTRAINT fk_note_evaluation_id FOREIGN KEY (evaluation_id) REFERENCES evaluation(id) ON DELETE RESTRICT;

ALTER TABLE note ADD CONSTRAINT fk_note_inscription_ue_id FOREIGN KEY (inscription_ue_id) REFERENCES inscription_ue(id) ON DELETE RESTRICT;

CREATE INDEX ix_note_inscription_ue_id ON note(inscription_ue_id);

ALTER TABLE note ADD CONSTRAINT fk_note_validateur_id FOREIGN KEY (validateur_id) REFERENCES enseignant(id) ON DELETE RESTRICT;

CREATE INDEX ix_note_validateur_id ON note(validateur_id);

ALTER TABLE historique_note ADD CONSTRAINT fk_historique_note_note_id FOREIGN KEY (note_id) REFERENCES note(id) ON DELETE RESTRICT;

ALTER TABLE historique_note ADD CONSTRAINT fk_historique_note_auteur_id FOREIGN KEY (auteur_id) REFERENCES utilisateur(id) ON DELETE RESTRICT;

CREATE INDEX ix_historique_note_auteur_id ON historique_note(auteur_id);

ALTER TABLE historique_note ADD CONSTRAINT fk_historique_note_decision_id FOREIGN KEY (decision_id) REFERENCES decision_requete(id) ON DELETE RESTRICT;

CREATE INDEX ix_historique_note_decision_id ON historique_note(decision_id);

ALTER TABLE requete ADD CONSTRAINT fk_requete_inscription_ue_id FOREIGN KEY (inscription_ue_id) REFERENCES inscription_ue(id) ON DELETE RESTRICT;

CREATE INDEX ix_requete_inscription_ue_id ON requete(inscription_ue_id);

ALTER TABLE requete ADD CONSTRAINT fk_requete_matiere_id FOREIGN KEY (matiere_id) REFERENCES matiere(id) ON DELETE RESTRICT;

CREATE INDEX ix_requete_matiere_id ON requete(matiere_id);

ALTER TABLE requete ADD CONSTRAINT fk_requete_evaluation_id FOREIGN KEY (evaluation_id) REFERENCES evaluation(id) ON DELETE RESTRICT;

CREATE INDEX ix_requete_evaluation_id ON requete(evaluation_id);

ALTER TABLE requete ADD CONSTRAINT fk_requete_note_id FOREIGN KEY (note_id) REFERENCES note(id) ON DELETE RESTRICT;

CREATE INDEX ix_requete_note_id ON requete(note_id);

ALTER TABLE requete ADD CONSTRAINT fk_requete_bulletin_conteste_id FOREIGN KEY (bulletin_conteste_id) REFERENCES bulletin(id) ON DELETE RESTRICT;

CREATE INDEX ix_requete_bulletin_conteste_id ON requete(bulletin_conteste_id);

ALTER TABLE justificatif ADD CONSTRAINT fk_justificatif_requete_id FOREIGN KEY (requete_id) REFERENCES requete(id) ON DELETE RESTRICT;

CREATE INDEX ix_justificatif_requete_id ON justificatif(requete_id);

ALTER TABLE decision_requete ADD CONSTRAINT fk_decision_requete_requete_id FOREIGN KEY (requete_id) REFERENCES requete(id) ON DELETE RESTRICT;

ALTER TABLE decision_requete ADD CONSTRAINT fk_decision_requete_enseignant_id FOREIGN KEY (enseignant_id) REFERENCES enseignant(id) ON DELETE RESTRICT;

CREATE INDEX ix_decision_requete_enseignant_id ON decision_requete(enseignant_id);

ALTER TABLE session_rattrapage ADD CONSTRAINT fk_session_rattrapage_classe_id FOREIGN KEY (classe_id) REFERENCES classe(id) ON DELETE RESTRICT;

CREATE INDEX ix_session_rattrapage_classe_id ON session_rattrapage(classe_id);

ALTER TABLE candidature_rattrapage ADD CONSTRAINT fk_candidature_rattra_session_id FOREIGN KEY (session_id) REFERENCES session_rattrapage(id) ON DELETE RESTRICT;

CREATE INDEX ix_candidature_rattrapage_session_id ON candidature_rattrapage(session_id);

ALTER TABLE candidature_rattrapage ADD CONSTRAINT fk_candidature_rattra_inscription_ue_id FOREIGN KEY (inscription_ue_id) REFERENCES inscription_ue(id) ON DELETE RESTRICT;

CREATE INDEX ix_candidature_rattrapage_inscription_ue_id ON candidature_rattrapage(inscription_ue_id);

ALTER TABLE candidature_rattrapage ADD CONSTRAINT fk_candidature_rattra_matiere_id FOREIGN KEY (matiere_id) REFERENCES matiere(id) ON DELETE RESTRICT;

CREATE INDEX ix_candidature_rattrapage_matiere_id ON candidature_rattrapage(matiere_id);

ALTER TABLE candidature_rattrapage ADD CONSTRAINT fk_candidature_rattra_etudiant_id FOREIGN KEY (etudiant_id) REFERENCES etudiant(id) ON DELETE RESTRICT;

ALTER TABLE candidature_rattrapage ADD CONSTRAINT fk_candidature_rattra_annee_id FOREIGN KEY (annee_id) REFERENCES annee_academique(id) ON DELETE RESTRICT;

CREATE INDEX ix_candidature_rattrapage_annee_id ON candidature_rattrapage(annee_id);

ALTER TABLE candidature_rattrapage ADD CONSTRAINT fk_candidature_rattra_niveau_id FOREIGN KEY (niveau_id) REFERENCES niveau(id) ON DELETE RESTRICT;

CREATE INDEX ix_candidature_rattrapage_niveau_id ON candidature_rattrapage(niveau_id);

ALTER TABLE candidature_rattrapage ADD CONSTRAINT fk_candidature_rattra_bulletin_source_id FOREIGN KEY (bulletin_source_id) REFERENCES bulletin(id) ON DELETE RESTRICT;

CREATE INDEX ix_candidature_rattrapage_bulletin_source_id ON candidature_rattrapage(bulletin_source_id);

ALTER TABLE candidature_rattrapage ADD CONSTRAINT fk_candidature_rattra_evaluation_origine_id FOREIGN KEY (evaluation_origine_id) REFERENCES evaluation(id) ON DELETE RESTRICT;

CREATE INDEX ix_candidature_rattrapage_evaluation_origine_id ON candidature_rattrapage(evaluation_origine_id);

ALTER TABLE candidature_rattrapage ADD CONSTRAINT fk_candidature_rattra_evaluation_rattrapage_id FOREIGN KEY (evaluation_rattrapage_id) REFERENCES evaluation(id) ON DELETE RESTRICT;

CREATE INDEX ix_candidature_rattrapage_evaluation_rattrapage_id ON candidature_rattrapage(evaluation_rattrapage_id);

ALTER TABLE candidature_rattrapage ADD CONSTRAINT fk_candidature_rattra_autorisation_id FOREIGN KEY (autorisation_id) REFERENCES decision_requete(id) ON DELETE RESTRICT;

CREATE INDEX ix_candidature_rattrapage_autorisation_id ON candidature_rattrapage(autorisation_id);

ALTER TABLE publication ADD CONSTRAINT fk_publication_classe_id FOREIGN KEY (classe_id) REFERENCES classe(id) ON DELETE RESTRICT;

ALTER TABLE publication ADD CONSTRAINT fk_publication_agent_publicateur_id FOREIGN KEY (agent_publicateur_id) REFERENCES utilisateur(id) ON DELETE RESTRICT;

CREATE INDEX ix_publication_agent_publicateur_id ON publication(agent_publicateur_id);

ALTER TABLE publication ADD CONSTRAINT fk_publication_publication_precedente_id FOREIGN KEY (publication_precedente_id) REFERENCES publication(id) ON DELETE RESTRICT;

CREATE INDEX ix_publication_publication_precedente_i ON publication(publication_precedente_id);

ALTER TABLE bulletin ADD CONSTRAINT fk_bulletin_publication_id FOREIGN KEY (publication_id) REFERENCES publication(id) ON DELETE RESTRICT;

ALTER TABLE bulletin ADD CONSTRAINT fk_bulletin_inscription_classe_id FOREIGN KEY (inscription_classe_id) REFERENCES inscription_classe(id) ON DELETE RESTRICT;

ALTER TABLE notification ADD CONSTRAINT fk_notification_destinataire_id FOREIGN KEY (destinataire_id) REFERENCES utilisateur(id) ON DELETE RESTRICT;

ALTER TABLE notification ADD CONSTRAINT fk_notification_evaluation_id FOREIGN KEY (evaluation_id) REFERENCES evaluation(id) ON DELETE RESTRICT;

CREATE INDEX ix_notification_evaluation_id ON notification(evaluation_id);

ALTER TABLE notification ADD CONSTRAINT fk_notification_requete_id FOREIGN KEY (requete_id) REFERENCES requete(id) ON DELETE RESTRICT;

CREATE INDEX ix_notification_requete_id ON notification(requete_id);

ALTER TABLE journal_audit ADD CONSTRAINT fk_journal_audit_acteur_id FOREIGN KEY (acteur_id) REFERENCES utilisateur(id) ON DELETE RESTRICT;

CREATE INDEX ix_journal_audit_acteur_id ON journal_audit(acteur_id);

CREATE UNIQUE INDEX uq_login ON utilisateur(lower(login));
CREATE UNIQUE INDEX uq_affectation_active ON affectation(matiere_id,classe_id) WHERE actif;
CREATE UNIQUE INDEX uq_plan_version_classe ON plan_evaluation(affectation_id,version_plan) WHERE portee='CLASSE';
CREATE UNIQUE INDEX uq_plan_version_etudiant ON plan_evaluation(affectation_id,inscription_ue_id,version_plan) WHERE portee='ETUDIANT';
CREATE UNIQUE INDEX uq_plan_actif_classe ON plan_evaluation(affectation_id) WHERE portee='CLASSE' AND statut_plan='ACTIF';
CREATE UNIQUE INDEX uq_plan_actif_etudiant ON plan_evaluation(affectation_id,inscription_ue_id) WHERE portee='ETUDIANT' AND statut_plan='ACTIF';
CREATE UNIQUE INDEX uq_decision_courante ON decision_requete(requete_id) WHERE courante;
CREATE UNIQUE INDEX uq_bulletin_courant ON bulletin(inscription_classe_id,periode) WHERE courant;
CREATE INDEX ix_requetes_attente ON requete(statut_requete,date_soumission);
CREATE INDEX ix_evaluations_date ON evaluation(statut_evaluation,date_evaluation);
CREATE INDEX ix_notifications_envoi ON notification(statut_envoi,date_envoi);

-- Fonctions et triggers : search_path fixé pour éviter les objets homonymes.
CREATE FUNCTION exiger(ok boolean, message text) RETURNS void LANGUAGE plpgsql SET search_path=gnu,pg_catalog AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION '%',message USING ERRCODE='23514'; END IF; END $$;
CREATE FUNCTION acteur() RETURNS bigint LANGUAGE sql STABLE SET search_path=gnu,pg_catalog AS $$
 SELECT nullif(current_setting('gnu.acteur_id',true),'')::bigint $$;
CREATE FUNCTION figer_references() RETURNS trigger LANGUAGE plpgsql SET search_path=gnu,pg_catalog AS $$
DECLARE c text;
BEGIN
 FOREACH c IN ARRAY TG_ARGV LOOP
  IF to_jsonb(OLD)->c <> 'null'::jsonb AND (to_jsonb(OLD)->c) IS DISTINCT FROM (to_jsonb(NEW)->c) THEN
   RAISE EXCEPTION 'Référence % immuable dans %',c,TG_TABLE_NAME USING ERRCODE='23514';
  END IF;
 END LOOP;
 NEW.updated_at:=statement_timestamp(); RETURN NEW;
END $$;
CREATE FUNCTION interdire_ecriture() RETURNS trigger LANGUAGE plpgsql SET search_path=gnu,pg_catalog AS $$
BEGIN RAISE EXCEPTION 'Objet % conservé : opération % interdite',TG_TABLE_NAME,TG_OP USING ERRCODE='23514'; END $$;
CREATE FUNCTION snapshot_immuable() RETURNS trigger LANGUAGE plpgsql SET search_path=gnu,pg_catalog AS $$
BEGIN
 PERFORM exiger((to_jsonb(NEW)-'courant'-'courante'-'updated_at')=(to_jsonb(OLD)-'courant'-'courante'-'updated_at'),'Contenu publié ou décision immuable');
 RETURN NEW;
END $$;
CREATE VIEW contexte_inscription AS
SELECT iu.id inscription_ue_id,iu.ue_id,iu.type_inscription,ic.id inscription_classe_id,ic.etudiant_id,
 c.id classe_id,c.annee_id,c.niveau_id,c.version_programme
FROM inscription_ue iu JOIN inscription_classe ic ON ic.id=iu.inscription_classe_id JOIN classe c ON c.id=ic.classe_id;
CREATE VIEW contexte_evaluation AS
SELECT e.*,a.matiere_id,a.classe_id,a.enseignant_id,m.ue_id
FROM evaluation e JOIN affectation a ON a.id=e.affectation_id JOIN matiere m ON m.id=a.matiere_id;

CREATE FUNCTION controle_catalogue() RETURNS trigger LANGUAGE plpgsql SET search_path=gnu,pg_catalog AS $$
DECLARE u ue; nb integer;
BEGIN
 IF TG_TABLE_NAME='ue' THEN
  IF TG_OP='UPDATE' AND OLD.statut_catalogue<>'BROUILLON' THEN
   PERFORM exiger((to_jsonb(NEW)-'statut_catalogue'-'updated_at')=(to_jsonb(OLD)-'statut_catalogue'-'updated_at'),'Créer une version de programme au lieu de modifier cette UE');
   PERFORM exiger(NEW.statut_catalogue<>'BROUILLON','Catalogue archivé non réouvrable');
  END IF;
  IF NEW.statut_catalogue='ACTIF' THEN
   SELECT count(*) INTO nb FROM matiere WHERE ue_id=NEW.id;
   PERFORM exiger(nb BETWEEN 1 AND 2,'Une UE active doit comporter un ou deux EC');
  END IF;
 ELSE
  SELECT * INTO u FROM ue WHERE id=CASE WHEN TG_OP='DELETE' THEN OLD.ue_id ELSE NEW.ue_id END FOR UPDATE;
  PERFORM exiger(u.statut_catalogue='BROUILLON','Les EC d’une UE activée sont immuables');
  IF TG_OP<>'DELETE' THEN
   PERFORM id FROM niveau WHERE id=u.niveau_id FOR UPDATE;
   PERFORM exiger(NOT EXISTS(SELECT 1 FROM matiere mm JOIN ue uu ON uu.id=mm.ue_id WHERE uu.niveau_id=u.niveau_id AND uu.version_programme=u.version_programme AND mm.code_m=NEW.code_m AND mm.id<>NEW.id),'Code EC déjà utilisé dans cette version du niveau');
  END IF;
 END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
END $$;
CREATE TRIGGER a_catalogue BEFORE INSERT OR UPDATE ON ue FOR EACH ROW EXECUTE FUNCTION controle_catalogue();
CREATE TRIGGER a_catalogue BEFORE INSERT OR UPDATE OR DELETE ON matiere FOR EACH ROW EXECUTE FUNCTION controle_catalogue();

CREATE FUNCTION controle_liens() RETURNS trigger LANGUAGE plpgsql SET search_path=gnu,pg_catalog AS $$
DECLARE c classe; u ue; m matiere; a affectation; e contexte_evaluation; ci contexte_inscription; b bulletin; ic inscription_classe; s jsonb; other record;
BEGIN
 CASE TG_TABLE_NAME
 WHEN 'etudiant','enseignant' THEN
  PERFORM exiger(EXISTS(SELECT 1 FROM utilisateur WHERE id=NEW.utilisateur_id AND role=CASE WHEN TG_TABLE_NAME='etudiant' THEN 'ETUDIANT' ELSE 'ENSEIGNANT' END),'Rôle du profil incompatible');
 WHEN 'utilisateur' THEN
  IF TG_OP='UPDATE' THEN PERFORM exiger(NEW.role=OLD.role,'Rôle existant immuable; créer le profil approprié'); END IF;
 WHEN 'classe' THEN
  IF TG_OP='UPDATE' THEN PERFORM exiger(NEW.version_programme=OLD.version_programme,'Version de classe immuable'); END IF;
 WHEN 'inscription_ue' THEN
  SELECT * INTO ic FROM inscription_classe WHERE id=NEW.inscription_classe_id;
  SELECT * INTO c FROM classe WHERE id=ic.classe_id;
  SELECT * INTO u FROM ue WHERE id=NEW.ue_id;
  PERFORM exiger(u.niveau_id=c.niveau_id AND u.version_programme=c.version_programme AND u.statut_catalogue='ACTIF','UE étrangère au programme actif de la classe');
  IF NEW.type_inscription<>'NORMALE' THEN
   SELECT * INTO b FROM bulletin WHERE id=NEW.bulletin_source_id;
   SELECT sic.etudiant_id,sa.date_fin INTO other FROM inscription_classe sic JOIN classe sc ON sc.id=sic.classe_id JOIN annee_academique sa ON sa.id=sc.annee_id WHERE sic.id=b.inscription_classe_id;
   PERFORM exiger(other.etudiant_id=ic.etudiant_id AND other.date_fin<(SELECT date_debut FROM annee_academique WHERE id=c.annee_id),'Source de reprise : autre étudiant ou année non antérieure');
   SELECT value INTO s FROM jsonb_array_elements(b.contenu_fige->'ues') WHERE (value->>'ue_id')::bigint=NEW.ue_source_id;
   PERFORM exiger(s IS NOT NULL,'UE source absente du bulletin');
   PERFORM exiger(EXISTS(SELECT 1 FROM ue us WHERE us.id=NEW.ue_source_id AND us.code_ue=u.code_ue AND us.niveau_id=u.niveau_id),'Correspondance des UE non établie');
   IF NEW.type_inscription='CONSERVEE' THEN PERFORM exiger((s->>'el')::boolean=false AND (s->>'arrondi')::numeric>=50,'UE non conservable');
   ELSE PERFORM exiger((s->>'el')::boolean OR (s->>'arrondi')::numeric<50,'Cette UE doit être conservée'); END IF;
  END IF;
  IF TG_OP='UPDATE' THEN PERFORM exiger(NEW.type_inscription=OLD.type_inscription,'Type inscription immuable'); END IF;
 WHEN 'affectation' THEN
  SELECT * INTO m FROM matiere WHERE id=NEW.matiere_id; SELECT * INTO u FROM ue WHERE id=m.ue_id; SELECT * INTO c FROM classe WHERE id=NEW.classe_id;
  PERFORM exiger(u.niveau_id=c.niveau_id AND u.version_programme=c.version_programme,'Affectation hors programme');
 WHEN 'evaluation' THEN
  IF NEW.mode_evaluation='RATTRAPAGE' THEN
   SELECT * INTO e FROM contexte_evaluation WHERE id=NEW.evaluation_origine_id;
   SELECT * INTO a FROM affectation WHERE id=NEW.affectation_id;
   PERFORM exiger(e.mode_evaluation='NORMALE' AND e.matiere_id=a.matiere_id AND e.classe_id=a.classe_id AND e.type_eval=NEW.type_eval,'Origine du rattrapage incohérente');
  END IF;
  IF TG_OP='UPDATE' THEN
   PERFORM exiger(NEW.type_eval=OLD.type_eval AND NEW.mode_evaluation=OLD.mode_evaluation,'Type et mode immuables');
   IF EXISTS(SELECT 1 FROM note WHERE evaluation_id=OLD.id) THEN
    PERFORM exiger(NEW.date_evaluation=OLD.date_evaluation AND NEW.statut_evaluation=OLD.statut_evaluation,'Évaluation déjà notée : date et statut figés');
   END IF;
  END IF;
 END CASE;
 RETURN NEW;
END $$;
CREATE FUNCTION controle_plan() RETURNS trigger LANGUAGE plpgsql SET search_path=gnu,pg_catalog AS $$
DECLARE p plan_evaluation; a affectation; e contexte_evaluation; ci contexte_inscription; d decision_requete; r requete; somme numeric;
BEGIN
 IF TG_TABLE_NAME='ligne_plan' THEN
  SELECT * INTO p FROM plan_evaluation WHERE id=CASE WHEN TG_OP='DELETE' THEN OLD.plan_id ELSE NEW.plan_id END FOR UPDATE;
  PERFORM exiger(p.statut_plan='BROUILLON','Lignes d’un plan actif ou archivé immuables');
  IF TG_OP='DELETE' THEN RETURN OLD; END IF;
  SELECT * INTO a FROM affectation WHERE id=p.affectation_id;
  SELECT * INTO e FROM contexte_evaluation WHERE id=NEW.evaluation_id;
  PERFORM exiger(e.matiere_id=a.matiere_id AND e.classe_id=a.classe_id AND e.mode_evaluation='NORMALE','Évaluation étrangère au plan ou rattrapage compté deux fois');
 ELSE
  SELECT * INTO a FROM affectation WHERE id=NEW.affectation_id;
  IF TG_OP='UPDATE' AND OLD.statut_plan<>'BROUILLON' THEN
   PERFORM exiger((to_jsonb(OLD)-'statut_plan'-'updated_at')=(to_jsonb(NEW)-'statut_plan'-'updated_at') AND NEW.statut_plan<>'BROUILLON','Créer une nouvelle version du plan');
  END IF;
  IF NEW.portee='ETUDIANT' THEN
   SELECT * INTO p FROM plan_evaluation WHERE id=NEW.plan_commun_id;
   SELECT * INTO ci FROM contexte_inscription WHERE inscription_ue_id=NEW.inscription_ue_id;
   SELECT * INTO d FROM decision_requete WHERE id=NEW.decision_id;
   SELECT * INTO r FROM requete WHERE id=d.requete_id;
   PERFORM exiger(p.portee='CLASSE' AND p.affectation_id=NEW.affectation_id AND ci.classe_id=a.classe_id AND r.inscription_ue_id=ci.inscription_ue_id AND r.matiere_id=a.matiere_id AND d.action_decision<>'REJETER','Plan individuel sans décision cohérente');
  END IF;
  IF NEW.statut_plan='ACTIF' THEN
   SELECT sum(poids_evaluation) INTO somme FROM ligne_plan WHERE plan_id=NEW.id AND retenue;
   PERFORM exiger(somme=100,'Les poids retenus doivent totaliser 100');
  END IF;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER a_plan BEFORE INSERT OR UPDATE ON plan_evaluation FOR EACH ROW EXECUTE FUNCTION controle_plan();
CREATE TRIGGER a_ligne BEFORE INSERT OR UPDATE OR DELETE ON ligne_plan FOR EACH ROW EXECUTE FUNCTION controle_plan();

CREATE FUNCTION requete_dans_delai(publication_ts timestamptz, soumission_ts timestamptz) RETURNS boolean LANGUAGE sql IMMUTABLE STRICT SET search_path=gnu,pg_catalog AS $$
 SELECT soumission_ts BETWEEN publication_ts AND publication_ts + interval '48 hours' $$;
CREATE FUNCTION controle_requete() RETURNS trigger LANGUAGE plpgsql SET search_path=gnu,pg_catalog AS $$
DECLARE ci contexte_inscription; b bulletin; pub publication; oldb bulletin; e contexte_evaluation; ns jsonb; os jsonb; cible bigint;
BEGIN
 SELECT * INTO ci FROM contexte_inscription WHERE inscription_ue_id=NEW.inscription_ue_id;
 SELECT * INTO b FROM bulletin WHERE id=NEW.bulletin_conteste_id;
 SELECT * INTO pub FROM publication WHERE id=b.publication_id;
 PERFORM exiger(b.inscription_classe_id=ci.inscription_classe_id AND EXISTS(SELECT 1 FROM matiere WHERE id=NEW.matiere_id AND ue_id=ci.ue_id),'Requête hors bulletin/UE');
 IF NEW.evaluation_id IS NOT NULL THEN
  SELECT * INTO e FROM contexte_evaluation WHERE id=NEW.evaluation_id;
  PERFORM exiger(e.matiere_id=NEW.matiere_id AND e.classe_id=ci.classe_id,'Évaluation étrangère à la requête');
 END IF;
 IF NEW.note_id IS NOT NULL THEN
  PERFORM exiger(EXISTS(SELECT 1 FROM note n JOIN contexte_evaluation ev ON ev.id=n.evaluation_id WHERE n.id=NEW.note_id AND n.inscription_ue_id=NEW.inscription_ue_id AND ev.matiere_id=NEW.matiere_id AND (NEW.evaluation_id IS NULL OR n.evaluation_id=NEW.evaluation_id)),'Note étrangère à la requête');
 END IF;
 IF TG_OP='INSERT' THEN
  PERFORM exiger(EXISTS(SELECT 1 FROM etudiant et JOIN utilisateur us ON us.id=et.utilisateur_id WHERE et.id=ci.etudiant_id AND us.id=acteur() AND us.actif),'La requête doit être soumise par l’étudiant concerné');
  NEW.date_soumission:=statement_timestamp();
  PERFORM exiger(requete_dans_delai(pub.date_publication,NEW.date_soumission),'Délai de requête de 48 h dépassé');
  IF pub.publication_precedente_id IS NOT NULL THEN
   SELECT * INTO oldb FROM bulletin WHERE publication_id=pub.publication_precedente_id AND inscription_classe_id=ci.inscription_classe_id;
   SELECT ec INTO ns FROM jsonb_array_elements(b.contenu_fige->'ues') u CROSS JOIN LATERAL jsonb_array_elements(u->'ecs') ec WHERE (ec->>'matiere_id')::bigint=NEW.matiere_id;
   SELECT ec INTO os FROM jsonb_array_elements(oldb.contenu_fige->'ues') u CROSS JOIN LATERAL jsonb_array_elements(u->'ecs') ec WHERE (ec->>'matiere_id')::bigint=NEW.matiere_id;
   IF NEW.note_id IS NOT NULL OR NEW.evaluation_id IS NOT NULL THEN
    SELECT coalesce(ev.evaluation_origine_id,ev.id) INTO cible FROM evaluation ev WHERE ev.id=coalesce(NEW.evaluation_id,(SELECT evaluation_id FROM note WHERE id=NEW.note_id));
    SELECT value INTO ns FROM jsonb_array_elements(ns->'sources') WHERE (value->>'evaluation_origine_id')::bigint=cible;
    SELECT value INTO os FROM jsonb_array_elements(os->'sources') WHERE (value->>'evaluation_origine_id')::bigint=cible;
   END IF;
   PERFORM exiger(ns IS NOT NULL AND ns IS DISTINCT FROM os,'La republication ne corrige pas cette note ou cet EC');
  END IF;
 ELSE
  PERFORM exiger(EXISTS(SELECT 1 FROM affectation af JOIN enseignant en ON en.id=af.enseignant_id WHERE af.actif AND af.classe_id=ci.classe_id AND af.matiere_id=NEW.matiere_id AND en.utilisateur_id=acteur()),'Traitement réservé à l’enseignant');
  PERFORM exiger((to_jsonb(NEW)-'statut_requete'-'updated_at')=(to_jsonb(OLD)-'statut_requete'-'updated_at'),'Contenu d’une requête soumise immuable');
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER a_requete BEFORE INSERT OR UPDATE ON requete FOR EACH ROW EXECUTE FUNCTION controle_requete();
CREATE FUNCTION preuve_requise() RETURNS trigger LANGUAGE plpgsql SET search_path=gnu,pg_catalog AS $$
DECLARE rid bigint;
BEGIN
 IF TG_TABLE_NAME='requete' THEN rid:=NEW.id; ELSE rid:=OLD.requete_id; END IF;
 IF EXISTS(SELECT 1 FROM requete WHERE id=rid AND type_requete='ABSENCE') THEN
  PERFORM exiger(EXISTS(SELECT 1 FROM justificatif WHERE requete_id=rid),'Absence : justificatif obligatoire');
 END IF; RETURN NULL;
END $$;
CREATE CONSTRAINT TRIGGER preuve_requise AFTER INSERT OR UPDATE ON requete DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION preuve_requise();
CREATE CONSTRAINT TRIGGER preuve_conservee AFTER DELETE ON justificatif DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION preuve_requise();
CREATE FUNCTION controle_decision() RETURNS trigger LANGUAGE plpgsql SET search_path=gnu,pg_catalog AS $$
BEGIN
 PERFORM exiger(EXISTS(SELECT 1 FROM requete r JOIN contexte_inscription ci ON ci.inscription_ue_id=r.inscription_ue_id JOIN affectation a ON a.matiere_id=r.matiere_id AND a.classe_id=ci.classe_id JOIN enseignant en ON en.id=a.enseignant_id JOIN utilisateur us ON us.id=en.utilisateur_id WHERE r.id=NEW.requete_id AND a.actif AND en.id=NEW.enseignant_id AND us.id=acteur() AND us.actif),'Décision réservée à l’enseignant affecté');
 NEW.date_decision:=statement_timestamp(); RETURN NEW;
END $$;
CREATE TRIGGER a_decision BEFORE INSERT ON decision_requete FOR EACH ROW EXECUTE FUNCTION controle_decision();
CREATE TRIGGER a_decision_immuable BEFORE UPDATE ON decision_requete FOR EACH ROW EXECUTE FUNCTION snapshot_immuable();
CREATE FUNCTION controle_candidature() RETURNS trigger LANGUAGE plpgsql SET search_path=gnu,pg_catalog AS $$
DECLARE ci contexte_inscription; ev contexte_evaluation; er contexte_evaluation; b bulletin; res jsonb; au decision_requete; req requete;
BEGIN
 SELECT * INTO ci FROM contexte_inscription WHERE inscription_ue_id=NEW.inscription_ue_id;
 SELECT * INTO ev FROM contexte_evaluation WHERE id=NEW.evaluation_origine_id;
 PERFORM exiger(EXISTS(SELECT 1 FROM affectation af JOIN enseignant en ON en.id=af.enseignant_id JOIN utilisateur us ON us.id=en.utilisateur_id WHERE af.actif AND af.classe_id=ci.classe_id AND af.matiere_id=NEW.matiere_id AND us.id=acteur() AND us.actif),'Gestion du rattrapage réservée à l’enseignant');
 IF NEW.date_consommation IS NOT NULL AND (TG_OP='INSERT' OR OLD.date_consommation IS NULL) THEN
  PERFORM exiger(pg_trigger_depth()>1,'La consommation est produite par la validation de la note');
 END IF;
 PERFORM exiger(ev.mode_evaluation='NORMALE' AND ev.matiere_id=NEW.matiere_id AND ev.classe_id=ci.classe_id AND ev.ue_id=ci.ue_id,'Candidature hors EC/classe');
 NEW.etudiant_id:=ci.etudiant_id; NEW.annee_id:=ci.annee_id; NEW.niveau_id:=ci.niveau_id;
 SELECT code_m INTO NEW.code_m_scope FROM matiere WHERE id=NEW.matiere_id;
 IF TG_OP='UPDATE' AND OLD.date_consommation IS NOT NULL THEN
  PERFORM exiger(NEW.date_consommation=OLD.date_consommation AND NEW.evaluation_rattrapage_id=OLD.evaluation_rattrapage_id AND NEW.session_id IS NOT DISTINCT FROM OLD.session_id AND NEW.statut_candidature IN ('COMPOSEE','ABSENTE'),'Un rattrapage consommé ne peut être réinitialisé');
 END IF;
 SELECT * INTO b FROM bulletin WHERE id=NEW.bulletin_source_id;
 PERFORM exiger(b.inscription_classe_id=ci.inscription_classe_id,'Bulletin source étranger');
 IF NEW.session_id IS NOT NULL THEN
  PERFORM exiger(EXISTS(SELECT 1 FROM session_rattrapage WHERE id=NEW.session_id AND classe_id=ci.classe_id),'Session étrangère à la classe');
 END IF;
 IF ev.type_eval='SN' THEN
  SELECT ec INTO res FROM jsonb_array_elements(b.contenu_fige->'ues') u CROSS JOIN LATERAL jsonb_array_elements(u->'ecs') ec WHERE (ec->>'matiere_id')::bigint=NEW.matiere_id;
  PERFORM exiger((res->>'arrondi')::numeric<50 AND NOT (res->>'el')::boolean,'Rattrapage SN réservé à EC arrondi < 50');
 ELSE
  PERFORM exiger(NEW.autorisation_id IS NOT NULL,'CC/TP : requête approuvée obligatoire');
 END IF;
 IF NEW.autorisation_id IS NOT NULL THEN
  SELECT * INTO au FROM decision_requete WHERE id=NEW.autorisation_id;
  SELECT * INTO req FROM requete WHERE id=au.requete_id;
  PERFORM exiger(au.action_decision='AUTORISER_EVALUATION' AND req.inscription_ue_id=NEW.inscription_ue_id AND req.matiere_id=NEW.matiere_id,'Autorisation incohérente');
 END IF;
 IF NEW.evaluation_rattrapage_id IS NOT NULL THEN
  SELECT * INTO er FROM contexte_evaluation WHERE id=NEW.evaluation_rattrapage_id;
  PERFORM exiger(er.mode_evaluation='RATTRAPAGE' AND er.evaluation_origine_id=ev.id,'Mauvaise épreuve de rattrapage');
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER a_candidature BEFORE INSERT OR UPDATE ON candidature_rattrapage FOR EACH ROW EXECUTE FUNCTION controle_candidature();

CREATE FUNCTION controle_note() RETURNS trigger LANGUAGE plpgsql SET search_path=gnu,pg_catalog AS $$
DECLARE ci contexte_inscription; ev contexte_evaluation; en enseignant; cand candidature_rattrapage;
BEGIN
 SELECT * INTO ci FROM contexte_inscription WHERE inscription_ue_id=NEW.inscription_ue_id;
 SELECT * INTO ev FROM contexte_evaluation WHERE id=NEW.evaluation_id;
 SELECT * INTO en FROM enseignant WHERE utilisateur_id=acteur();
 PERFORM exiger(ci.classe_id=ev.classe_id AND ci.ue_id=ev.ue_id AND ci.type_inscription<>'CONSERVEE','Note hors inscription/classe ou UE conservée');
 PERFORM exiger(EXISTS(SELECT 1 FROM affectation a JOIN utilisateur u ON u.id=en.utilisateur_id WHERE a.matiere_id=ev.matiere_id AND a.classe_id=ci.classe_id AND a.enseignant_id=en.id AND a.actif AND u.actif),'Saisie réservée à l’enseignant responsable actif');
 PERFORM exiger(EXISTS(SELECT 1 FROM inscription_ue iu JOIN inscription_classe ic ON ic.id=iu.inscription_classe_id WHERE iu.id=NEW.inscription_ue_id AND iu.statut_inscription='VALIDEE' AND ic.statut_inscription='VALIDEE'),'Inscription non validée');
 PERFORM exiger(ev.statut_evaluation='REALISEE','Évaluation non réalisée');
 PERFORM exiger(nullif(btrim(current_setting('gnu.motif',true)),'') IS NOT NULL,'Motif de saisie/correction obligatoire');
 IF nullif(current_setting('gnu.decision_id',true),'') IS NOT NULL THEN
  PERFORM exiger(EXISTS(SELECT 1 FROM decision_requete dr JOIN requete rq ON rq.id=dr.requete_id WHERE dr.id=nullif(current_setting('gnu.decision_id',true),'')::bigint AND rq.inscription_ue_id=NEW.inscription_ue_id AND rq.matiere_id=ev.matiere_id AND dr.action_decision<>'REJETER'),'Décision étrangère ou rejetée');
 END IF;
 IF TG_OP='UPDATE' THEN
  PERFORM exiger(NEW.version_note=OLD.version_note,'Version obsolète : relire la note avant modification');
  NEW.version_note:=OLD.version_note+1;
 ELSE NEW.version_note:=1; END IF;
 IF NEW.statut_note='VALIDEE' THEN
  NEW.validateur_id:=en.id; NEW.date_validation:=statement_timestamp();
 ELSE NEW.validateur_id:=NULL; NEW.date_validation:=NULL; END IF;
 IF ev.mode_evaluation='RATTRAPAGE' THEN
  SELECT * INTO cand FROM candidature_rattrapage WHERE inscription_ue_id=NEW.inscription_ue_id AND matiere_id=ev.matiere_id FOR UPDATE;
  PERFORM exiger(cand.evaluation_rattrapage_id=NEW.evaluation_id AND cand.statut_candidature IN ('AUTORISEE','PROGRAMMEE','COMPOSEE','ABSENTE'),'Rattrapage non autorisé ou autre tentative');
  IF NEW.statut_note='VALIDEE' AND NEW.situation IN ('NUMERIQUE','ABSENTE') THEN
   UPDATE candidature_rattrapage SET date_consommation=coalesce(date_consommation,statement_timestamp()),statut_candidature=CASE WHEN NEW.situation='ABSENTE' THEN 'ABSENTE' ELSE 'COMPOSEE' END WHERE id=cand.id;
  END IF;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER a_note BEFORE INSERT OR UPDATE ON note FOR EACH ROW EXECUTE FUNCTION controle_note();
CREATE FUNCTION historiser_note() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=gnu,pg_catalog AS $$
BEGIN
 INSERT INTO historique_note(note_id,version_note,auteur_id,date_modification,motif,origine_modification,decision_id,reference_jury,avant,apres)
 VALUES(NEW.id,NEW.version_note,acteur(),statement_timestamp(),current_setting('gnu.motif',true),
 coalesce(nullif(current_setting('gnu.origine',true),''),CASE WHEN TG_OP='INSERT' THEN 'SAISIE' ELSE 'CORRECTION' END),
 nullif(current_setting('gnu.decision_id',true),'')::bigint,nullif(current_setting('gnu.reference_jury',true),''),CASE WHEN TG_OP='UPDATE' THEN to_jsonb(OLD) ELSE NULL END,to_jsonb(NEW));
 RETURN NULL;
END $$;
CREATE TRIGGER historique_note_auto AFTER INSERT OR UPDATE ON note FOR EACH ROW EXECUTE FUNCTION historiser_note();
CREATE FUNCTION historique_auto_seulement() RETURNS trigger LANGUAGE plpgsql SET search_path=gnu,pg_catalog AS $$
BEGIN PERFORM exiger(pg_trigger_depth()>1,'Historique produit uniquement par le trigger de note'); RETURN NEW; END $$;
CREATE TRIGGER a_historique_auto BEFORE INSERT ON historique_note FOR EACH ROW EXECUTE FUNCTION historique_auto_seulement();

CREATE FUNCTION grade_ue(n integer) RETURNS text LANGUAGE sql IMMUTABLE STRICT SET search_path=gnu,pg_catalog AS $$
 SELECT CASE WHEN n NOT BETWEEN 0 AND 100 THEN NULL WHEN n>=80 THEN 'A+' WHEN n>=75 THEN 'A−' WHEN n>=70 THEN 'B+' WHEN n>=65 THEN 'B' WHEN n>=60 THEN 'B−' WHEN n>=55 THEN 'C+' WHEN n>=50 THEN 'C' WHEN n>=45 THEN 'C−' WHEN n>=40 THEN 'D+' WHEN n>=35 THEN 'D−' WHEN n>=30 THEN 'E' ELSE 'F' END $$;
CREATE FUNCTION points_ue(n integer) RETURNS numeric LANGUAGE sql IMMUTABLE STRICT SET search_path=gnu,pg_catalog AS $$
 SELECT CASE WHEN n NOT BETWEEN 0 AND 100 THEN NULL WHEN n>=80 THEN 4 WHEN n>=75 THEN 3.7 WHEN n>=70 THEN 3.3 WHEN n>=65 THEN 3 WHEN n>=60 THEN 2.7 WHEN n>=55 THEN 2.3 WHEN n>=50 THEN 2 WHEN n>=45 THEN 1.7 WHEN n>=40 THEN 1.3 WHEN n>=35 THEN 1 ELSE 0 END $$;
CREATE FUNCTION calculer_ec(iu bigint, mid bigint) RETURNS jsonb LANGUAGE plpgsql SET search_path=gnu,pg_catalog AS $$
DECLARE ci contexte_inscription; p plan_evaluation; l record; n note; c candidature_rattrapage; resultat numeric:=0; elim boolean:=false; sources jsonb:='[]'; a affectation; total numeric;
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
  IF n.situation='ABSENTE' AND c.id IS NOT NULL THEN elim:=true;
  ELSE PERFORM exiger(n.situation='NUMERIQUE','Absence normale non résolue'); resultat:=resultat+n.valeur_note*l.poids_evaluation/100; END IF;
  sources:=sources||jsonb_build_array(jsonb_build_object('evaluation_origine_id',l.evaluation_id,'evaluation_id',n.evaluation_id,'note_id',n.id,'version_note',n.version_note,'valeur',n.valeur_note,'situation',n.situation,'poids',l.poids_evaluation));
 END LOOP;
 RETURN jsonb_build_object('matiere_id',mid,'code_m',(SELECT code_m FROM matiere WHERE id=mid),'credit',(SELECT credit_matiere FROM matiere WHERE id=mid),'plan_id',p.id,'version_plan',p.version_plan,'sources',sources,'el',elim,'brut',CASE WHEN elim THEN NULL ELSE resultat END,'arrondi',CASE WHEN elim THEN NULL ELSE ceil(resultat) END);
END $$;
CREATE FUNCTION calculer_ue(iuid bigint) RETURNS jsonb LANGUAGE plpgsql SET search_path=gnu,pg_catalog AS $$
DECLARE iu inscription_ue; u ue; m matiere; r jsonb; ecs jsonb:='[]'; total numeric:=0; credits numeric:=0; elim boolean:=false; valeur integer; brut numeric;
BEGIN
 SELECT * INTO iu FROM inscription_ue WHERE id=iuid; SELECT * INTO u FROM ue WHERE id=iu.ue_id;
 PERFORM exiger(iu.statut_inscription='VALIDEE','Inscription UE non validée');
 IF iu.type_inscription='CONSERVEE' THEN
  SELECT value INTO r FROM bulletin b CROSS JOIN LATERAL jsonb_array_elements(b.contenu_fige->'ues') WHERE b.id=iu.bulletin_source_id AND (value->>'ue_id')::bigint=iu.ue_source_id;
  RETURN r||jsonb_build_object('ue_id',iu.ue_id,'inscription_ue_id',iu.id,'credit',u.credit_ue,'semestre',u.numero_semestre,'source_bulletin_id',iu.bulletin_source_id,'ue_source_id',iu.ue_source_id);
 END IF;
 FOR m IN SELECT * FROM matiere WHERE ue_id=u.id ORDER BY rang_ec LOOP
  r:=calculer_ec(iuid,m.id); ecs:=ecs||jsonb_build_array(r); elim:=elim OR (r->>'el')::boolean;
  total:=total+coalesce((r->>'arrondi')::numeric,0)*m.credit_matiere; credits:=credits+m.credit_matiere;
 END LOOP;
 PERFORM exiger(credits>0,'UE sans EC'); brut:=total/credits; valeur:=ceil(brut);
 RETURN jsonb_build_object('inscription_ue_id',iu.id,'ue_id',u.id,'code_ue',u.code_ue,'version_programme',u.version_programme,'credit',u.credit_ue,'semestre',u.numero_semestre,'ecs',ecs,'el',elim,'brut',CASE WHEN elim THEN NULL ELSE brut END,'arrondi',CASE WHEN elim THEN NULL ELSE valeur END,'grade',CASE WHEN elim THEN 'EL' ELSE grade_ue(valeur) END,'points',CASE WHEN elim THEN 0 ELSE points_ue(valeur) END);
END $$;
CREATE FUNCTION calculer_bulletin(icid bigint, per text) RETURNS jsonb LANGUAGE plpgsql SET search_path=gnu,pg_catalog AS $$
DECLARE ic inscription_classe; c classe; iu inscription_ue; r jsonb; liste jsonb:='[]'; numer numeric:=0; den numeric:=0; n1 numeric:=0; d1 numeric:=0; n2 numeric:=0; d2 numeric:=0; admissible boolean:=true;
BEGIN
 PERFORM exiger(per IN ('S1','S2','ANNUELLE'),'Période inconnue');
 SELECT * INTO ic FROM inscription_classe WHERE id=icid; SELECT * INTO c FROM classe WHERE id=ic.classe_id;
 PERFORM exiger(ic.statut_inscription='VALIDEE','Inscription de classe non validée');
 PERFORM exiger(NOT EXISTS(SELECT 1 FROM ue u WHERE u.niveau_id=c.niveau_id AND u.version_programme=c.version_programme AND u.statut_catalogue='ACTIF' AND u.categorie_ue='FONDAMENTALE' AND (per='ANNUELLE' OR u.numero_semestre=CASE per WHEN 'S1' THEN 1 WHEN 'S2' THEN 2 END) AND NOT EXISTS(SELECT 1 FROM inscription_ue x WHERE x.inscription_classe_id=icid AND x.ue_id=u.id AND x.statut_inscription='VALIDEE')),'Inscription à une UE fondamentale manquante');
 FOR iu IN SELECT x.* FROM inscription_ue x JOIN ue ON ue.id=x.ue_id WHERE x.inscription_classe_id=icid AND x.statut_inscription='VALIDEE' AND (per='ANNUELLE' OR ue.numero_semestre=CASE per WHEN 'S1' THEN 1 WHEN 'S2' THEN 2 END) ORDER BY ue.numero_semestre,ue.id LOOP
  r:=calculer_ue(iu.id); liste:=liste||jsonb_build_array(r);
  numer:=numer+(r->>'points')::numeric*(r->>'credit')::numeric; den:=den+(r->>'credit')::numeric;
  IF (r->>'semestre')::integer=1 THEN n1:=n1+(r->>'points')::numeric*(r->>'credit')::numeric;d1:=d1+(r->>'credit')::numeric;
  ELSE n2:=n2+(r->>'points')::numeric*(r->>'credit')::numeric;d2:=d2+(r->>'credit')::numeric; END IF;
  admissible:=admissible AND NOT (r->>'el')::boolean AND coalesce((r->>'arrondi')::numeric>=35,false);
 END LOOP;
 PERFORM exiger(den>0,'Bulletin vide');
 RETURN jsonb_build_object('schema_version',1,'inscription_classe_id',icid,'periode',per,'ues',liste,'somme_points_credits',numer,'total_credits',den,'mgp_s1',n1/nullif(d1,0),'mgp_s2',n2/nullif(d2,0),'mgp_total',CASE WHEN per='ANNUELLE' THEN numer/den ELSE NULL END,'decision_admission',CASE WHEN per<>'ANNUELLE' THEN 'NON_APPLICABLE' WHEN admissible AND numer>=2*den THEN 'ADMIS' ELSE 'ECHEC' END,
 'identite',(SELECT jsonb_build_object('matricule',e.matricule,'nom',us.nom,'prenom',us.prenom,'classe',c.code_classe,'annee_id',c.annee_id) FROM etudiant e JOIN utilisateur us ON us.id=e.utilisateur_id WHERE e.id=ic.etudiant_id),
 'regles',jsonb_build_object('version','GNU-1.2','arrondi','CEIL_EC_PUIS_UE','el_points',0,'admission_ue_min',35,'admission_mgp_min',2,'sn_ec_max_exclusif',50,'requetes_heures',48,'tentatives_ec_annee',1),
 'bareme',(SELECT jsonb_agg(jsonb_build_object('minimum',v,'grade',grade_ue(v),'points',points_ue(v)) ORDER BY v) FROM unnest(ARRAY[0,30,35,40,45,50,55,60,65,70,75,80]) v));
END $$;
CREATE FUNCTION controle_publication() RETURNS trigger LANGUAGE plpgsql SET search_path=gnu,pg_catalog AS $$
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
  NEW.periode:=p.periode; NEW.version_bulletin:=p.version_publication;
  r:=calculer_bulletin(NEW.inscription_classe_id,p.periode);
  NEW.contenu_fige:=r; NEW.version_schema_contenu:=1;NEW.version_regles:='GNU-1.2';NEW.version_bareme:='GNU-GRADES-1';
  NEW.mgp_s1:=(r->>'mgp_s1')::numeric;NEW.mgp_s2:=(r->>'mgp_s2')::numeric;NEW.mgp_total:=(r->>'mgp_total')::numeric;
  NEW.somme_points_credits:=(r->>'somme_points_credits')::numeric;NEW.total_credits:=(r->>'total_credits')::numeric;NEW.decision_admission:=r->>'decision_admission';
 END IF; RETURN NEW;
END $$;
CREATE TRIGGER a_publication BEFORE INSERT ON publication FOR EACH ROW EXECUTE FUNCTION controle_publication();
CREATE TRIGGER a_bulletin BEFORE INSERT ON bulletin FOR EACH ROW EXECUTE FUNCTION controle_publication();
CREATE TRIGGER a_bulletin_fige BEFORE UPDATE ON bulletin FOR EACH ROW EXECUTE FUNCTION snapshot_immuable();
CREATE FUNCTION publication_complete() RETURNS trigger LANGUAGE plpgsql SET search_path=gnu,pg_catalog AS $$
BEGIN
 PERFORM exiger(EXISTS(SELECT 1 FROM bulletin WHERE publication_id=NEW.id),'Publication sans bulletin');
 PERFORM exiger(NOT EXISTS(SELECT 1 FROM inscription_classe ic WHERE ic.classe_id=NEW.classe_id AND ic.statut_inscription='VALIDEE' AND NOT EXISTS(SELECT 1 FROM bulletin b WHERE b.publication_id=NEW.id AND b.inscription_classe_id=ic.id)),'Publication de classe incomplète'); RETURN NULL;
END $$;
CREATE CONSTRAINT TRIGGER publication_complete AFTER INSERT ON publication DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION publication_complete();
CREATE FUNCTION publier_classe(cid bigint, per text) RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path=gnu,pg_catalog AS $$
DECLARE prev publication; pid bigint; ic record;
BEGIN
 PERFORM exiger(current_setting('transaction_isolation') IN ('repeatable read','serializable'),'Publication : utiliser BEGIN ISOLATION LEVEL REPEATABLE READ');
 -- Sérialiser les publications d’une même classe. Les notes sources sont verrouillées jusqu’au COMMIT.
 PERFORM id FROM classe WHERE id=cid FOR UPDATE;
 PERFORM n.id FROM note n JOIN contexte_inscription ci ON ci.inscription_ue_id=n.inscription_ue_id WHERE ci.classe_id=cid ORDER BY n.id FOR SHARE OF n;
 SELECT * INTO prev FROM publication WHERE classe_id=cid AND periode=per ORDER BY version_publication DESC LIMIT 1;
 INSERT INTO publication(classe_id,periode,version_publication,agent_publicateur_id,publication_precedente_id) VALUES(cid,per,coalesce(prev.version_publication,0)+1,acteur(),prev.id) RETURNING id INTO pid;
 FOR ic IN SELECT id FROM inscription_classe WHERE classe_id=cid AND statut_inscription='VALIDEE' ORDER BY id LOOP
  UPDATE bulletin SET courant=false WHERE inscription_classe_id=ic.id AND periode=per AND courant;
  INSERT INTO bulletin(publication_id,inscription_classe_id) VALUES(pid,ic.id);
 END LOOP;
 RETURN pid;
END $$;
CREATE VIEW liste_rattrapage_sn AS
SELECT b.id bulletin_source_id,b.publication_id,b.inscription_classe_id,(u->>'inscription_ue_id')::bigint inscription_ue_id,
 (u->>'ue_id')::bigint ue_id,(ec->>'matiere_id')::bigint matiere_id,(ec->>'arrondi')::numeric note_ec_arrondie,
 (src->>'evaluation_origine_id')::bigint evaluation_origine_id
FROM bulletin b CROSS JOIN LATERAL jsonb_array_elements(b.contenu_fige->'ues') u
CROSS JOIN LATERAL jsonb_array_elements(u->'ecs') ec CROSS JOIN LATERAL jsonb_array_elements(ec->'sources') src
JOIN evaluation e ON e.id=(src->>'evaluation_origine_id')::bigint
WHERE b.courant AND e.type_eval='SN' AND NOT (ec->>'el')::boolean AND (ec->>'arrondi')::numeric<50
AND NOT EXISTS(SELECT 1 FROM candidature_rattrapage c WHERE c.inscription_ue_id=(u->>'inscription_ue_id')::bigint AND c.matiere_id=(ec->>'matiere_id')::bigint AND c.date_consommation IS NOT NULL)
AND NOT (u ? 'source_bulletin_id');
CREATE FUNCTION nombre_jours_ouvrables(debut date, fin date, fermetures date[]) RETURNS integer LANGUAGE sql IMMUTABLE SET search_path=gnu,pg_catalog AS $$
SELECT count(*)::integer FROM generate_series(1,greatest(fin-debut,0)) d WHERE extract(isodow FROM debut+d)<=5 AND NOT (debut+d=ANY(coalesce(fermetures,ARRAY[]::date[]))) $$;
CREATE FUNCTION rappeler_notes(version_cal text, fuseau text, fermetures date[] DEFAULT ARRAY[]::date[]) RETURNS integer LANGUAGE plpgsql SET search_path=gnu,pg_catalog AS $$
DECLARE ev record; jour date:=(statement_timestamp() AT TIME ZONE fuseau)::date; ajout integer:=0; nb integer;
BEGIN
 FOR ev IN SELECT e.*,en.utilisateur_id FROM contexte_evaluation e JOIN enseignant en ON en.id=e.enseignant_id WHERE e.statut_evaluation='REALISEE' AND e.version_calendrier=version_cal LOOP
  IF nombre_jours_ouvrables((ev.date_evaluation AT TIME ZONE fuseau)::date,jour,fermetures)>=2 AND extract(isodow FROM jour)<=5 AND NOT (jour=ANY(fermetures)) AND EXISTS(
   SELECT 1 FROM contexte_inscription ci JOIN inscription_ue iu ON iu.id=ci.inscription_ue_id JOIN inscription_classe ic ON ic.id=ci.inscription_classe_id
   WHERE ci.classe_id=ev.classe_id AND ci.ue_id=ev.ue_id AND ci.type_inscription<>'CONSERVEE' AND iu.statut_inscription='VALIDEE' AND ic.statut_inscription='VALIDEE'
   AND (ev.mode_evaluation='NORMALE' OR EXISTS(SELECT 1 FROM candidature_rattrapage ca WHERE ca.inscription_ue_id=iu.id AND ca.evaluation_rattrapage_id=ev.id AND ca.statut_candidature<>'ANNULEE'))
   AND NOT EXISTS(SELECT 1 FROM note n WHERE n.inscription_ue_id=iu.id AND n.evaluation_id=ev.id AND n.statut_note='VALIDEE' AND n.situation<>'MANQUANTE')) THEN
    INSERT INTO notification(destinataire_id,evaluation_id,type_notification,cle_evenement,contenu,jour_ouvrable,statut_envoi)
    VALUES(ev.utilisateur_id,ev.id,'RAPPEL_NOTES','rappel:'||ev.id||':'||jour,jsonb_build_object('message','Notes à saisir ou valider','version_calendrier',version_cal,'fuseau',fuseau,'fermetures',to_jsonb(fermetures)),jour,'EN_ATTENTE') ON CONFLICT(destinataire_id,cle_evenement) DO NOTHING;
    GET DIAGNOSTICS nb=ROW_COUNT;ajout:=ajout+nb;
  END IF;
 END LOOP;RETURN ajout;
END $$;
CREATE VIEW effectifs_classes AS SELECT c.id,c.code_classe,count(ic.id) effectif FROM classe c LEFT JOIN inscription_classe ic ON ic.classe_id=c.id AND ic.statut_inscription='VALIDEE' GROUP BY c.id,c.code_classe;
CREATE FUNCTION journaliser() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=gnu,pg_catalog AS $$
DECLARE av jsonb; ap jsonb;
BEGIN
 IF TG_OP<>'INSERT' THEN av:=to_jsonb(OLD)-'mot_de_passe_hash'; END IF;
 IF TG_OP<>'DELETE' THEN ap:=to_jsonb(NEW)-'mot_de_passe_hash'; END IF;
 INSERT INTO journal_audit(acteur_id,origine,action,date_action,type_objet,identifiant_objet,avant,apres,motif)
 VALUES(acteur(),CASE WHEN acteur() IS NULL THEN 'SYSTEME' ELSE 'UTILISATEUR' END,TG_OP,statement_timestamp(),TG_TABLE_NAME,coalesce(ap->>'id',av->>'id'),av,ap,coalesce(nullif(current_setting('gnu.motif',true),''),'Opération SQL de gestion'));
 RETURN NULL;
END $$;

CREATE TRIGGER a_liens BEFORE INSERT OR UPDATE ON etudiant FOR EACH ROW EXECUTE FUNCTION controle_liens();
CREATE TRIGGER a_liens BEFORE INSERT OR UPDATE ON enseignant FOR EACH ROW EXECUTE FUNCTION controle_liens();
CREATE TRIGGER a_liens BEFORE INSERT OR UPDATE ON utilisateur FOR EACH ROW EXECUTE FUNCTION controle_liens();
CREATE TRIGGER a_liens BEFORE INSERT OR UPDATE ON classe FOR EACH ROW EXECUTE FUNCTION controle_liens();
CREATE TRIGGER a_liens BEFORE INSERT OR UPDATE ON inscription_ue FOR EACH ROW EXECUTE FUNCTION controle_liens();
CREATE TRIGGER a_liens BEFORE INSERT OR UPDATE ON affectation FOR EACH ROW EXECUTE FUNCTION controle_liens();
CREATE TRIGGER a_liens BEFORE INSERT OR UPDATE ON evaluation FOR EACH ROW EXECUTE FUNCTION controle_liens();
CREATE TRIGGER z_identite BEFORE UPDATE ON universite FOR EACH ROW EXECUTE FUNCTION figer_references('id');
CREATE TRIGGER z_identite BEFORE UPDATE ON faculte FOR EACH ROW EXECUTE FUNCTION figer_references('id','universite_id');
CREATE TRIGGER z_identite BEFORE UPDATE ON departement FOR EACH ROW EXECUTE FUNCTION figer_references('id','faculte_id');
CREATE TRIGGER z_identite BEFORE UPDATE ON filiere FOR EACH ROW EXECUTE FUNCTION figer_references('id','departement_id');
CREATE TRIGGER z_identite BEFORE UPDATE ON niveau FOR EACH ROW EXECUTE FUNCTION figer_references('id','filiere_id');
CREATE TRIGGER z_identite BEFORE UPDATE ON annee_academique FOR EACH ROW EXECUTE FUNCTION figer_references('id');
CREATE TRIGGER z_identite BEFORE UPDATE ON classe FOR EACH ROW EXECUTE FUNCTION figer_references('id','niveau_id','annee_id');
CREATE TRIGGER z_identite BEFORE UPDATE ON ue FOR EACH ROW EXECUTE FUNCTION figer_references('id','niveau_id');
CREATE TRIGGER z_identite BEFORE UPDATE ON matiere FOR EACH ROW EXECUTE FUNCTION figer_references('id','ue_id');
CREATE TRIGGER z_identite BEFORE UPDATE ON utilisateur FOR EACH ROW EXECUTE FUNCTION figer_references('id');
CREATE TRIGGER z_identite BEFORE UPDATE ON etudiant FOR EACH ROW EXECUTE FUNCTION figer_references('id','utilisateur_id');
CREATE TRIGGER z_identite BEFORE UPDATE ON enseignant FOR EACH ROW EXECUTE FUNCTION figer_references('id','utilisateur_id');
CREATE TRIGGER z_identite BEFORE UPDATE ON inscription_classe FOR EACH ROW EXECUTE FUNCTION figer_references('id','etudiant_id','classe_id');
CREATE TRIGGER z_identite BEFORE UPDATE ON inscription_ue FOR EACH ROW EXECUTE FUNCTION figer_references('id','inscription_classe_id','ue_id','bulletin_source_id','ue_source_id');
CREATE TRIGGER z_identite BEFORE UPDATE ON affectation FOR EACH ROW EXECUTE FUNCTION figer_references('id','enseignant_id','matiere_id','classe_id');
CREATE TRIGGER z_identite BEFORE UPDATE ON evaluation FOR EACH ROW EXECUTE FUNCTION figer_references('id','affectation_id','evaluation_origine_id');
CREATE TRIGGER z_identite BEFORE UPDATE ON plan_evaluation FOR EACH ROW EXECUTE FUNCTION figer_references('id','affectation_id','inscription_ue_id','decision_id','plan_commun_id');
CREATE TRIGGER z_identite BEFORE UPDATE ON ligne_plan FOR EACH ROW EXECUTE FUNCTION figer_references('id','plan_id','evaluation_id');
CREATE TRIGGER z_identite BEFORE UPDATE ON note FOR EACH ROW EXECUTE FUNCTION figer_references('id','evaluation_id','inscription_ue_id');
CREATE TRIGGER z_identite BEFORE UPDATE ON historique_note FOR EACH ROW EXECUTE FUNCTION figer_references('id','note_id','auteur_id','decision_id');
CREATE TRIGGER z_identite BEFORE UPDATE ON requete FOR EACH ROW EXECUTE FUNCTION figer_references('id','inscription_ue_id','matiere_id','evaluation_id','note_id','bulletin_conteste_id');
CREATE TRIGGER z_identite BEFORE UPDATE ON justificatif FOR EACH ROW EXECUTE FUNCTION figer_references('id','requete_id');
CREATE TRIGGER z_identite BEFORE UPDATE ON decision_requete FOR EACH ROW EXECUTE FUNCTION figer_references('id','requete_id','enseignant_id');
CREATE TRIGGER z_identite BEFORE UPDATE ON session_rattrapage FOR EACH ROW EXECUTE FUNCTION figer_references('id','classe_id');
CREATE TRIGGER z_identite BEFORE UPDATE ON candidature_rattrapage FOR EACH ROW EXECUTE FUNCTION figer_references('id','inscription_ue_id','matiere_id','etudiant_id','annee_id','niveau_id','bulletin_source_id','evaluation_origine_id');
CREATE TRIGGER z_identite BEFORE UPDATE ON publication FOR EACH ROW EXECUTE FUNCTION figer_references('id','classe_id','agent_publicateur_id','publication_precedente_id');
CREATE TRIGGER z_identite BEFORE UPDATE ON bulletin FOR EACH ROW EXECUTE FUNCTION figer_references('id','publication_id','inscription_classe_id');
CREATE TRIGGER z_identite BEFORE UPDATE ON notification FOR EACH ROW EXECUTE FUNCTION figer_references('id','destinataire_id','evaluation_id','requete_id');
CREATE TRIGGER z_identite BEFORE UPDATE ON journal_audit FOR EACH ROW EXECUTE FUNCTION figer_references('id','acteur_id');
CREATE TRIGGER immuable BEFORE UPDATE OR DELETE ON historique_note FOR EACH ROW EXECUTE FUNCTION interdire_ecriture();
CREATE TRIGGER immuable BEFORE UPDATE OR DELETE ON publication FOR EACH ROW EXECUTE FUNCTION interdire_ecriture();
CREATE TRIGGER immuable BEFORE UPDATE OR DELETE ON journal_audit FOR EACH ROW EXECUTE FUNCTION interdire_ecriture();
CREATE TRIGGER pas_de_suppression BEFORE DELETE ON note FOR EACH ROW EXECUTE FUNCTION interdire_ecriture();
CREATE TRIGGER pas_de_suppression BEFORE DELETE ON bulletin FOR EACH ROW EXECUTE FUNCTION interdire_ecriture();
CREATE TRIGGER pas_de_suppression BEFORE DELETE ON decision_requete FOR EACH ROW EXECUTE FUNCTION interdire_ecriture();
CREATE TRIGGER pas_de_suppression BEFORE DELETE ON candidature_rattrapage FOR EACH ROW EXECUTE FUNCTION interdire_ecriture();
CREATE TRIGGER pas_de_suppression BEFORE DELETE ON requete FOR EACH ROW EXECUTE FUNCTION interdire_ecriture();
CREATE TRIGGER pas_de_truncate BEFORE TRUNCATE ON universite FOR EACH STATEMENT EXECUTE FUNCTION interdire_ecriture();
CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON universite FOR EACH ROW EXECUTE FUNCTION journaliser();
CREATE TRIGGER pas_de_truncate BEFORE TRUNCATE ON faculte FOR EACH STATEMENT EXECUTE FUNCTION interdire_ecriture();
CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON faculte FOR EACH ROW EXECUTE FUNCTION journaliser();
CREATE TRIGGER pas_de_truncate BEFORE TRUNCATE ON departement FOR EACH STATEMENT EXECUTE FUNCTION interdire_ecriture();
CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON departement FOR EACH ROW EXECUTE FUNCTION journaliser();
CREATE TRIGGER pas_de_truncate BEFORE TRUNCATE ON filiere FOR EACH STATEMENT EXECUTE FUNCTION interdire_ecriture();
CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON filiere FOR EACH ROW EXECUTE FUNCTION journaliser();
CREATE TRIGGER pas_de_truncate BEFORE TRUNCATE ON niveau FOR EACH STATEMENT EXECUTE FUNCTION interdire_ecriture();
CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON niveau FOR EACH ROW EXECUTE FUNCTION journaliser();
CREATE TRIGGER pas_de_truncate BEFORE TRUNCATE ON annee_academique FOR EACH STATEMENT EXECUTE FUNCTION interdire_ecriture();
CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON annee_academique FOR EACH ROW EXECUTE FUNCTION journaliser();
CREATE TRIGGER pas_de_truncate BEFORE TRUNCATE ON classe FOR EACH STATEMENT EXECUTE FUNCTION interdire_ecriture();
CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON classe FOR EACH ROW EXECUTE FUNCTION journaliser();
CREATE TRIGGER pas_de_truncate BEFORE TRUNCATE ON ue FOR EACH STATEMENT EXECUTE FUNCTION interdire_ecriture();
CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON ue FOR EACH ROW EXECUTE FUNCTION journaliser();
CREATE TRIGGER pas_de_truncate BEFORE TRUNCATE ON matiere FOR EACH STATEMENT EXECUTE FUNCTION interdire_ecriture();
CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON matiere FOR EACH ROW EXECUTE FUNCTION journaliser();
CREATE TRIGGER pas_de_truncate BEFORE TRUNCATE ON utilisateur FOR EACH STATEMENT EXECUTE FUNCTION interdire_ecriture();
CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON utilisateur FOR EACH ROW EXECUTE FUNCTION journaliser();
CREATE TRIGGER pas_de_truncate BEFORE TRUNCATE ON etudiant FOR EACH STATEMENT EXECUTE FUNCTION interdire_ecriture();
CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON etudiant FOR EACH ROW EXECUTE FUNCTION journaliser();
CREATE TRIGGER pas_de_truncate BEFORE TRUNCATE ON enseignant FOR EACH STATEMENT EXECUTE FUNCTION interdire_ecriture();
CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON enseignant FOR EACH ROW EXECUTE FUNCTION journaliser();
CREATE TRIGGER pas_de_truncate BEFORE TRUNCATE ON inscription_classe FOR EACH STATEMENT EXECUTE FUNCTION interdire_ecriture();
CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON inscription_classe FOR EACH ROW EXECUTE FUNCTION journaliser();
CREATE TRIGGER pas_de_truncate BEFORE TRUNCATE ON inscription_ue FOR EACH STATEMENT EXECUTE FUNCTION interdire_ecriture();
CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON inscription_ue FOR EACH ROW EXECUTE FUNCTION journaliser();
CREATE TRIGGER pas_de_truncate BEFORE TRUNCATE ON affectation FOR EACH STATEMENT EXECUTE FUNCTION interdire_ecriture();
CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON affectation FOR EACH ROW EXECUTE FUNCTION journaliser();
CREATE TRIGGER pas_de_truncate BEFORE TRUNCATE ON evaluation FOR EACH STATEMENT EXECUTE FUNCTION interdire_ecriture();
CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON evaluation FOR EACH ROW EXECUTE FUNCTION journaliser();
CREATE TRIGGER pas_de_truncate BEFORE TRUNCATE ON plan_evaluation FOR EACH STATEMENT EXECUTE FUNCTION interdire_ecriture();
CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON plan_evaluation FOR EACH ROW EXECUTE FUNCTION journaliser();
CREATE TRIGGER pas_de_truncate BEFORE TRUNCATE ON ligne_plan FOR EACH STATEMENT EXECUTE FUNCTION interdire_ecriture();
CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON ligne_plan FOR EACH ROW EXECUTE FUNCTION journaliser();
CREATE TRIGGER pas_de_truncate BEFORE TRUNCATE ON note FOR EACH STATEMENT EXECUTE FUNCTION interdire_ecriture();
CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON note FOR EACH ROW EXECUTE FUNCTION journaliser();
CREATE TRIGGER pas_de_truncate BEFORE TRUNCATE ON historique_note FOR EACH STATEMENT EXECUTE FUNCTION interdire_ecriture();
CREATE TRIGGER pas_de_truncate BEFORE TRUNCATE ON requete FOR EACH STATEMENT EXECUTE FUNCTION interdire_ecriture();
CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON requete FOR EACH ROW EXECUTE FUNCTION journaliser();
CREATE TRIGGER pas_de_truncate BEFORE TRUNCATE ON justificatif FOR EACH STATEMENT EXECUTE FUNCTION interdire_ecriture();
CREATE TRIGGER pas_de_truncate BEFORE TRUNCATE ON decision_requete FOR EACH STATEMENT EXECUTE FUNCTION interdire_ecriture();
CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON decision_requete FOR EACH ROW EXECUTE FUNCTION journaliser();
CREATE TRIGGER pas_de_truncate BEFORE TRUNCATE ON session_rattrapage FOR EACH STATEMENT EXECUTE FUNCTION interdire_ecriture();
CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON session_rattrapage FOR EACH ROW EXECUTE FUNCTION journaliser();
CREATE TRIGGER pas_de_truncate BEFORE TRUNCATE ON candidature_rattrapage FOR EACH STATEMENT EXECUTE FUNCTION interdire_ecriture();
CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON candidature_rattrapage FOR EACH ROW EXECUTE FUNCTION journaliser();
CREATE TRIGGER pas_de_truncate BEFORE TRUNCATE ON publication FOR EACH STATEMENT EXECUTE FUNCTION interdire_ecriture();
CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON publication FOR EACH ROW EXECUTE FUNCTION journaliser();
CREATE TRIGGER pas_de_truncate BEFORE TRUNCATE ON bulletin FOR EACH STATEMENT EXECUTE FUNCTION interdire_ecriture();
CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON bulletin FOR EACH ROW EXECUTE FUNCTION journaliser();
CREATE TRIGGER pas_de_truncate BEFORE TRUNCATE ON notification FOR EACH STATEMENT EXECUTE FUNCTION interdire_ecriture();
CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON notification FOR EACH ROW EXECUTE FUNCTION journaliser();
CREATE TRIGGER pas_de_truncate BEFORE TRUNCATE ON journal_audit FOR EACH STATEMENT EXECUTE FUNCTION interdire_ecriture();

-- Rien n’est accordé à PUBLIC. L’installation est destinée à un propriétaire de schéma dédié.
REVOKE ALL ON ALL TABLES IN SCHEMA gnu FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA gnu FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA gnu FROM PUBLIC;
COMMENT ON SCHEMA gnu IS 'GNU schéma initial v1.0 — cahier 1.2';
COMMIT;
