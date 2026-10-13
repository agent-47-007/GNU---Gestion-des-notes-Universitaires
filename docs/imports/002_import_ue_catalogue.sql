-- GNU - import du catalogue UE Informatique
-- Prérequis : 001_structure_academique.sql exécuté.
-- Le fichier CSV est lu depuis la racine du projet.

BEGIN;
SET LOCAL search_path = gnu, public;

CREATE TEMP TABLE import_ue_catalogue (
  code_ue text NOT NULL,
  intitule text NOT NULL,
  niveau text NOT NULL,
  semestre smallint NOT NULL,
  categorie text NOT NULL,
  credits numeric NOT NULL,
  source text NOT NULL
) ON COMMIT DROP;

\copy import_ue_catalogue FROM 'docs/imports/ue_catalogue.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

INSERT INTO ue (
  code_ue, intitule_ue, niveau_id, version_programme, numero_semestre,
  categorie_ue, credit_ue, statut_catalogue
)
SELECT
  src.code_ue,
  src.intitule,
  n.id,
  1,
  src.semestre,
  src.categorie,
  src.credits,
  'BROUILLON'
FROM import_ue_catalogue src
JOIN niveau n ON n.code_niv = src.niveau
JOIN filiere f ON f.id = n.filiere_id AND f.code_f = 'INF'
JOIN departement d ON d.id = f.departement_id AND d.code_de = 'INFO'
ON CONFLICT (niveau_id, version_programme, code_ue) DO UPDATE SET
  intitule_ue = EXCLUDED.intitule_ue,
  numero_semestre = EXCLUDED.numero_semestre,
  categorie_ue = EXCLUDED.categorie_ue,
  credit_ue = EXCLUDED.credit_ue,
  statut_catalogue = CASE
    WHEN ue.statut_catalogue = 'ACTIF' THEN ue.statut_catalogue
    ELSE EXCLUDED.statut_catalogue
  END,
  updated_at = statement_timestamp();

COMMIT;
