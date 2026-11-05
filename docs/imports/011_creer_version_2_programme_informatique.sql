-- Crée la version 2 du programme Informatique à partir des grilles 2021.
-- Les niveaux, semestres, codes, crédits et classes de la version 1 restent inchangés.
-- Exécuter depuis la racine du dépôt avec un rôle autorisé à créer des UE et EC.

\i docs/imports/013_regle_ue_memoire_inf500.sql

BEGIN;
SET LOCAL search_path = gnu, public;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM gnu.ue u
    JOIN gnu.niveau n ON n.id = u.niveau_id
    JOIN gnu.filiere f ON f.id = n.filiere_id
    WHERE f.code_f = 'INF' AND u.version_programme = 2
  ) THEN
    RAISE EXCEPTION 'La version 2 du programme Informatique existe déjà; aucune ligne n’a été modifiée.';
  END IF;
END $$;

CREATE TEMP TABLE import_v2_ue (
  code_ue text PRIMARY KEY,
  intitule text NOT NULL,
  niveau text NOT NULL,
  semestre smallint NOT NULL CHECK (semestre IN (1,2)),
  categorie text NOT NULL CHECK (categorie IN ('FONDAMENTALE','OPTIONNELLE')),
  credits numeric NOT NULL CHECK (credits > 0),
  source text NOT NULL
) ON COMMIT DROP;

\copy import_v2_ue FROM 'docs/imports/ue_catalogue.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

DO $$
DECLARE missing text;
BEGIN
  SELECT string_agg(src.code_ue, ', ' ORDER BY src.code_ue)
    INTO missing
  FROM import_v2_ue src
  WHERE NOT EXISTS (
    SELECT 1 FROM gnu.niveau n
    JOIN gnu.filiere f ON f.id = n.filiere_id AND f.code_f = 'INF'
    JOIN gnu.departement d ON d.id = f.departement_id AND d.code_de = 'INFO'
    WHERE n.code_niv = src.niveau
  );
  IF missing IS NOT NULL THEN
    RAISE EXCEPTION 'Niveaux Informatique absents du référentiel: %', missing;
  END IF;
END $$;

INSERT INTO gnu.ue (
  code_ue, intitule_ue, niveau_id, version_programme, numero_semestre,
  categorie_ue, credit_ue, statut_catalogue, created_at, updated_at
)
SELECT src.code_ue, src.intitule, n.id, 2, src.semestre,
       src.categorie, src.credits, 'BROUILLON', statement_timestamp(), statement_timestamp()
FROM import_v2_ue src
JOIN gnu.niveau n ON n.code_niv = src.niveau
JOIN gnu.filiere f ON f.id = n.filiere_id AND f.code_f = 'INF'
JOIN gnu.departement d ON d.id = f.departement_id AND d.code_de = 'INFO';

CREATE TEMP TABLE import_v2_ec (
  code_m text PRIMARY KEY,
  intitule_matiere text NOT NULL,
  code_ue text NOT NULL,
  rang_ec smallint NOT NULL CHECK (rang_ec IN (1,2)),
  credit_matiere numeric NOT NULL CHECK (credit_matiere > 0),
  source text NOT NULL
) ON COMMIT DROP;

\copy import_v2_ec FROM 'docs/imports/ec_catalogue.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

DO $$
DECLARE n integer; missing text;
BEGIN
  SELECT count(*), string_agg(DISTINCT src.code_ue, ', ' ORDER BY src.code_ue)
    INTO n, missing
  FROM import_v2_ec src
  WHERE NOT EXISTS (
    SELECT 1 FROM gnu.ue u
    JOIN gnu.niveau niv ON niv.id = u.niveau_id
    JOIN gnu.filiere f ON f.id = niv.filiere_id AND f.code_f = 'INF'
    WHERE u.code_ue = src.code_ue AND u.version_programme = 2
  );
  IF n > 0 THEN
    RAISE EXCEPTION 'EC sans UE correspondante dans la version 2: %', missing;
  END IF;
  IF (SELECT count(*) FROM import_v2_ue) <> 73 THEN
    RAISE EXCEPTION 'Le syllabus doit fournir 73 UE; lignes lues: %', (SELECT count(*) FROM import_v2_ue);
  END IF;
  IF (SELECT count(*) FROM import_v2_ec) <> 144 THEN
    RAISE EXCEPTION 'Le syllabus doit fournir 144 EC; lignes lues: %', (SELECT count(*) FROM import_v2_ec);
  END IF;
END $$;

INSERT INTO gnu.matiere (
  code_m, intitule_matiere, ue_id, rang_ec, credit_matiere, created_at, updated_at
)
SELECT src.code_m, src.intitule_matiere, u.id, src.rang_ec, src.credit_matiere,
       statement_timestamp(), statement_timestamp()
FROM import_v2_ec src
JOIN gnu.ue u ON u.code_ue = src.code_ue AND u.version_programme = 2
JOIN gnu.niveau n ON n.id = u.niveau_id
JOIN gnu.filiere f ON f.id = n.filiere_id AND f.code_f = 'INF';

UPDATE gnu.ue u
SET statut_catalogue = 'ACTIF', updated_at = statement_timestamp()
WHERE u.version_programme = 2
  AND (
    (
      (SELECT count(*) FROM gnu.matiere m WHERE m.ue_id = u.id) BETWEEN 1 AND 2
      AND (SELECT COALESCE(sum(m.credit_matiere), 0) FROM gnu.matiere m WHERE m.ue_id = u.id) = u.credit_ue
    )
    OR (
      u.code_ue = 'INF500'
      AND EXISTS (
        SELECT 1 FROM gnu.niveau n
        JOIN gnu.filiere f ON f.id = n.filiere_id AND f.code_f = 'INF'
        WHERE n.id = u.niveau_id AND n.code_niv = 'M2'
      )
      AND u.numero_semestre = 2
      AND u.credit_ue = 60
      AND NOT EXISTS (SELECT 1 FROM gnu.matiere m WHERE m.ue_id = u.id)
    )
  );

DO $$
DECLARE active_count integer; draft_codes text;
BEGIN
  SELECT count(*) INTO active_count
  FROM gnu.ue u
  JOIN gnu.niveau n ON n.id = u.niveau_id
  JOIN gnu.filiere f ON f.id = n.filiere_id AND f.code_f = 'INF'
  WHERE u.version_programme = 2 AND u.statut_catalogue = 'ACTIF';

  SELECT string_agg(u.code_ue, ', ' ORDER BY u.code_ue) INTO draft_codes
  FROM gnu.ue u
  JOIN gnu.niveau n ON n.id = u.niveau_id
  JOIN gnu.filiere f ON f.id = n.filiere_id AND f.code_f = 'INF'
  WHERE u.version_programme = 2 AND u.statut_catalogue = 'BROUILLON';

  IF active_count <> 73 OR draft_codes IS NOT NULL THEN
    RAISE EXCEPTION 'Catalogue v2 incomplet: % UE actives, UE en brouillon: %', active_count, draft_codes;
  END IF;
END $$;

COMMIT;
