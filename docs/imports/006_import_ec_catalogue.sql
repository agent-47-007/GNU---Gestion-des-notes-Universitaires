-- Import idempotent des EC extraits des programmes Licence/Master.
-- Chaque mise à jour remplace le contenu de l’EC de même rang dans l’unique UE.
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
      AND u.version_programme = 1
      AND f.code_f = 'INF'
  );
  IF n > 0 THEN
    RAISE EXCEPTION 'EC rattachés à une UE Informatique introuvable: % ligne(s) (UE: %)', n, missing;
  END IF;
END $$;

-- Supprime les EC retirés d’une UE mise à jour uniquement s’ils ne sont
-- référencés par aucune donnée académique.
CREATE TEMP TABLE import_ec_catalogue_obsolete ON COMMIT DROP AS
SELECT m.id
FROM gnu.matiere m
JOIN gnu.ue u ON u.id = m.ue_id AND u.version_programme = 1
JOIN gnu.niveau n ON n.id = u.niveau_id
JOIN gnu.filiere f ON f.id = n.filiere_id AND f.code_f = 'INF'
WHERE EXISTS (
    SELECT 1 FROM import_ec_catalogue src
    WHERE src.code_ue = u.code_ue
)
AND NOT EXISTS (
    SELECT 1 FROM import_ec_catalogue src
    WHERE src.code_ue = u.code_ue
      AND src.rang_ec = m.rang_ec
);

DO $$
DECLARE fk record; found_reference boolean;
BEGIN
  FOR fk IN
    SELECT c.conrelid::regclass AS relation_name,
           a.attname AS column_name,
           array_length(c.conkey, 1) AS column_count
    FROM pg_constraint c
    JOIN LATERAL unnest(c.conkey) key(attnum) ON true
    JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = key.attnum
    WHERE c.contype = 'f' AND c.confrelid = 'gnu.matiere'::regclass
  LOOP
    IF fk.column_count <> 1 THEN
      RAISE EXCEPTION 'Référence composée vers gnu.matiere dans %; import annulé.', fk.relation_name;
    END IF;
    EXECUTE format(
      'SELECT EXISTS (SELECT 1 FROM %s WHERE %I IN (SELECT id FROM pg_temp.import_ec_catalogue_obsolete))',
      fk.relation_name, fk.column_name
    ) INTO found_reference;
    IF found_reference THEN
      RAISE EXCEPTION 'Des données de % utilisent un EC que le catalogue met à jour; import annulé.', fk.relation_name;
    END IF;
  END LOOP;
END $$;

DELETE FROM gnu.matiere m
USING import_ec_catalogue_obsolete obsolete
WHERE m.id = obsolete.id;

-- Des codes EC peuvent changer pendant une mise à jour. Les libérer d’abord
-- permet de conserver les identifiants des EC et de leurs notes en les
-- remplaçant au même rang.
UPDATE gnu.matiere m
SET code_m = 'TMP' || m.id::text
FROM gnu.ue u
JOIN gnu.niveau n ON n.id = u.niveau_id
JOIN gnu.filiere f ON f.id = n.filiere_id AND f.code_f = 'INF'
JOIN import_ec_catalogue src
  ON src.code_ue = u.code_ue
WHERE m.ue_id = u.id
  AND u.version_programme = 1
  AND m.rang_ec = src.rang_ec
  AND m.code_m <> src.code_m;

INSERT INTO gnu.matiere (code_m, intitule_matiere, ue_id, rang_ec, credit_matiere)
SELECT src.code_m, src.intitule_matiere, u.id, src.rang_ec, src.credit_matiere
FROM import_ec_catalogue src
JOIN gnu.ue u ON u.code_ue = src.code_ue AND u.version_programme = 1
JOIN niveau n ON n.id = u.niveau_id
JOIN filiere f ON f.id = n.filiere_id AND f.code_f = 'INF'
ON CONFLICT (ue_id, rang_ec) DO UPDATE SET
  code_m = EXCLUDED.code_m,
  intitule_matiere = EXCLUDED.intitule_matiere,
  credit_matiere = EXCLUDED.credit_matiere,
  updated_at = statement_timestamp();

-- Activation contrôlée : uniquement les UE possédant exactement 1 ou 2 EC.
UPDATE ue u
SET statut_catalogue = 'ACTIF', updated_at = statement_timestamp()
WHERE u.statut_catalogue <> 'ACTIF'
  AND u.version_programme = 1
  AND EXISTS (SELECT 1 FROM niveau n JOIN filiere f ON f.id = n.filiere_id
              WHERE n.id = u.niveau_id AND f.code_f = 'INF')
  AND (SELECT count(*) FROM matiere m WHERE m.ue_id = u.id) BETWEEN 1 AND 2
  AND (SELECT COALESCE(sum(m.credit_matiere), 0) FROM matiere m WHERE m.ue_id = u.id) = u.credit_ue;

COMMIT;
