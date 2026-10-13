-- Import idempotent des EC extraits des programmes Licence/Master.
-- Prérequis : 001_structure_academique.sql et 002_import_ue_catalogue.sql.

BEGIN;
SET LOCAL search_path = gnu, public;

CREATE TEMP TABLE import_ec_catalogue (
  code_m text NOT NULL,
  intitule_matiere text NOT NULL,
  code_ue text NOT NULL,
  rang_ec smallint NOT NULL,
  credit_matiere numeric NOT NULL,
  source text NOT NULL,
  CHECK (rang_ec IN (1, 2)),
  CHECK (credit_matiere > 0)
) ON COMMIT DROP;

\copy import_ec_catalogue FROM 'docs/imports/ec_catalogue.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

-- Chaque code UE doit résoudre vers une UE Informatique unique.
DO $$
DECLARE n integer;
  missing text;
BEGIN
  SELECT count(*), string_agg(DISTINCT src.code_ue, ', ' ORDER BY src.code_ue)
    INTO n, missing
  FROM import_ec_catalogue src
  WHERE NOT EXISTS (
    SELECT 1
    FROM ue u
    JOIN niveau niv ON niv.id = u.niveau_id
    JOIN filiere f ON f.id = niv.filiere_id
    WHERE u.code_ue = src.code_ue
      AND f.code_f = 'INF'
  );
  IF n > 0 THEN
    RAISE EXCEPTION 'EC rattachés à une UE Informatique introuvable: % ligne(s) (UE: %)', n, missing;
  END IF;
END $$;

INSERT INTO matiere (code_m, intitule_matiere, ue_id, rang_ec, credit_matiere)
SELECT src.code_m, src.intitule_matiere, u.id, src.rang_ec, src.credit_matiere
FROM import_ec_catalogue src
JOIN ue u ON u.code_ue = src.code_ue
JOIN niveau n ON n.id = u.niveau_id
JOIN filiere f ON f.id = n.filiere_id AND f.code_f = 'INF'
ON CONFLICT (ue_id, code_m) DO UPDATE SET
  intitule_matiere = EXCLUDED.intitule_matiere,
  rang_ec = EXCLUDED.rang_ec,
  credit_matiere = EXCLUDED.credit_matiere,
  updated_at = statement_timestamp();

-- Activation contrôlée : uniquement les UE possédant exactement 1 ou 2 EC.
UPDATE ue u
SET statut_catalogue = 'ACTIF', updated_at = statement_timestamp()
WHERE u.statut_catalogue <> 'ACTIF'
  AND EXISTS (SELECT 1 FROM niveau n JOIN filiere f ON f.id = n.filiere_id
              WHERE n.id = u.niveau_id AND f.code_f = 'INF')
  AND (SELECT count(*) FROM matiere m WHERE m.ue_id = u.id) BETWEEN 1 AND 2
  AND (SELECT COALESCE(sum(m.credit_matiere), 0) FROM matiere m WHERE m.ue_id = u.id) = u.credit_ue;

COMMIT;
