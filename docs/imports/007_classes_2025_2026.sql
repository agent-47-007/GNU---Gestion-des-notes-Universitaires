-- Création des classes annuelles Informatique pour 2025-2026.
-- Les étudiants seront inscrits dans un script séparé après validation de leur année.
BEGIN;
SET LOCAL search_path = gnu, public;

INSERT INTO annee_academique (libelle, date_debut, date_fin)
VALUES ('2025-2026', DATE '2025-10-01', DATE '2026-07-31')
ON CONFLICT (libelle) DO NOTHING;

INSERT INTO classe (code_classe, niveau_id, annee_id, version_programme)
SELECT 'INF-' || n.code_niv || '-2025-2026', n.id, a.id, 1
FROM niveau n
JOIN filiere f ON f.id = n.filiere_id AND f.code_f = 'INF'
JOIN annee_academique a ON a.libelle = '2025-2026'
WHERE n.code_niv IN ('L1','L2','L3','M1','M2')
ON CONFLICT (niveau_id, annee_id) DO NOTHING;

COMMIT;
