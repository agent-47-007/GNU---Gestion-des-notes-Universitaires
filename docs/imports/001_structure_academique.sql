-- GNU - structure académique de référence
-- Exécution : psql -h 127.0.0.1 -p 5435 -U <utilisateur> -d gnu_notes -v ON_ERROR_STOP=1 -f 001_structure_academique.sql
-- Ce script ne supprime aucune donnée et peut être rejoué.

BEGIN;
SET LOCAL search_path = gnu, public;

INSERT INTO universite (code_univ, nom_univ)
VALUES ('UY1', 'Université de Yaoundé I')
ON CONFLICT (code_univ) DO UPDATE SET nom_univ = EXCLUDED.nom_univ, updated_at = statement_timestamp();

INSERT INTO faculte (code_fac, nom_fac, universite_id)
SELECT 'FS', 'Faculté des Sciences', id FROM universite WHERE code_univ = 'UY1'
ON CONFLICT (universite_id, code_fac) DO UPDATE SET nom_fac = EXCLUDED.nom_fac, updated_at = statement_timestamp();

INSERT INTO departement (code_de, nom_depart, faculte_id)
SELECT 'INFO', 'Département d’Informatique', f.id
FROM faculte f JOIN universite u ON u.id = f.universite_id
WHERE u.code_univ = 'UY1' AND f.code_fac = 'FS'
ON CONFLICT (faculte_id, code_de) DO UPDATE SET nom_depart = EXCLUDED.nom_depart, updated_at = statement_timestamp();

INSERT INTO filiere (code_f, nom_f, departement_id)
SELECT 'INF', 'Informatique', d.id
FROM departement d JOIN faculte f ON f.id = d.faculte_id
WHERE f.code_fac = 'FS' AND d.code_de = 'INFO'
ON CONFLICT (departement_id, code_f) DO UPDATE SET nom_f = EXCLUDED.nom_f, updated_at = statement_timestamp();

INSERT INTO niveau (code_niv, cycle_niv, libelle_niv, filiere_id)
SELECT v.code_niv, v.cycle_niv, v.libelle_niv, f.id
FROM (VALUES
  ('L1', 'LICENCE', 'Licence 1'),
  ('L2', 'LICENCE', 'Licence 2'),
  ('L3', 'LICENCE', 'Licence 3'),
  ('M1', 'MASTER', 'Master 1'),
  ('M2', 'MASTER', 'Master 2')
) AS v(code_niv, cycle_niv, libelle_niv)
JOIN filiere f ON f.code_f = 'INF'
JOIN departement d ON d.id = f.departement_id AND d.code_de = 'INFO'
ON CONFLICT (filiere_id, code_niv) DO UPDATE SET cycle_niv = EXCLUDED.cycle_niv, libelle_niv = EXCLUDED.libelle_niv, updated_at = statement_timestamp();

-- Les programmes de référence sont datés de 2021, mais ils ne sont pas une
-- inscription étudiante 2021-2022. Les dates seront complétées selon le
-- calendrier académique officiel avant insertion définitive.
INSERT INTO annee_academique (libelle, date_debut, date_fin)
VALUES
  ('2021-2022', DATE '2021-10-01', DATE '2022-09-30'),
  ('2024-2025', DATE '2024-10-01', DATE '2025-09-30'),
  ('2025-2026', DATE '2025-10-01', DATE '2026-09-30')
ON CONFLICT (libelle) DO NOTHING;

COMMIT;
