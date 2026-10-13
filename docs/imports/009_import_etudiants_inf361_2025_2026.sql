-- Import des étudiants INF361-SR pour l'année académique 2025-2026.
BEGIN;
SET LOCAL search_path = gnu, public;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TEMP TABLE import_etudiants (
  numero integer NOT NULL,
  matricule text NOT NULL,
  nom text NOT NULL,
  prenom text NOT NULL
) ON COMMIT DROP;

\copy import_etudiants FROM 'docs/imports/inf361_sr_students.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

INSERT INTO utilisateur (code_utilisateur, login, mot_de_passe_hash, role, nom, prenom)
SELECT
  'ETU-' || upper(i.matricule),
  lower(i.matricule),
  crypt('GNU-' || i.matricule, gen_salt('bf')),
  'ETUDIANT',
  i.nom,
  i.prenom
FROM import_etudiants i
ON CONFLICT (code_utilisateur) DO UPDATE SET
  nom = EXCLUDED.nom,
  prenom = EXCLUDED.prenom,
  updated_at = statement_timestamp();

INSERT INTO etudiant (matricule, utilisateur_id)
SELECT i.matricule, u.id
FROM import_etudiants i
JOIN utilisateur u ON u.code_utilisateur = 'ETU-' || upper(i.matricule)
ON CONFLICT (matricule) DO NOTHING;

INSERT INTO inscription_classe (etudiant_id, classe_id, statut_redoublant, statut_inscription)
SELECT e.id, c.id, false, 'BROUILLON'
FROM import_etudiants i
JOIN etudiant e ON e.matricule = i.matricule
JOIN classe c ON c.code_classe = 'INF-L3-2025-2026'
ON CONFLICT (etudiant_id, classe_id) DO NOTHING;

INSERT INTO inscription_ue (inscription_classe_id, ue_id, type_inscription, statut_inscription)
SELECT ic.id, u.id, 'NORMALE', 'BROUILLON'
FROM inscription_classe ic
JOIN classe c ON c.id = ic.classe_id AND c.code_classe = 'INF-L3-2025-2026'
JOIN ue u ON u.niveau_id = c.niveau_id AND u.statut_catalogue = 'ACTIF'
ON CONFLICT (inscription_classe_id, ue_id) DO NOTHING;

COMMIT;
