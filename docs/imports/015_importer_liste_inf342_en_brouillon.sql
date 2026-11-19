-- Import prudent de la liste INF342 comme demandes d'inscription en brouillon.
-- Hypothèse de travail : année 2025-2026, déduite de la répartition Fonda
-- 2025-2026 et des dates du classeur. Vérifiez la classe cible avant exécution.
-- Depuis la racine du dépôt, de préférence d'abord sur gnu_notes_recette.
-- Les comptes étudiants absents ne sont PAS créés; leurs matricules sont affichés.
-- Les notes et présences du classeur ne sont PAS importées.

BEGIN;
SET LOCAL search_path = gnu, public;

CREATE TEMP TABLE import_inf342_source (
  ligne_source integer NOT NULL,
  numero integer NOT NULL,
  nom_prenoms_source text NOT NULL,
  matricule_source text NOT NULL,
  matricule_normalise text NOT NULL
) ON COMMIT DROP;

\copy import_inf342_source FROM 'backend/storage/app/imports/official_2025_2026/inf342_etudiants_valides_source.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

DO $$
DECLARE
  n integer;
  d integer;
  classes integer;
BEGIN
  SELECT count(*) INTO n FROM import_inf342_source;
  SELECT count(*) - count(DISTINCT matricule_normalise) INTO d FROM import_inf342_source;
  SELECT count(*) INTO classes FROM gnu.classe WHERE code_classe = 'INF-L3-2025-2026';
  IF n <> 235 THEN
    RAISE EXCEPTION 'Import annulé: % lignes valides chargées, 235 attendues.', n;
  END IF;
  IF d <> 0 THEN
    RAISE EXCEPTION 'Import annulé: % matricules dupliqués.', d;
  END IF;
  IF classes <> 1 THEN
    RAISE EXCEPTION 'Import annulé: la classe INF-L3-2025-2026 est absente ou ambiguë.';
  END IF;
END $$;

-- Rapport avant insertion : les profils absents demandent une création/validation
-- de compte séparée via le parcours officiel.
SELECT count(*) AS lignes_source,
       count(*) FILTER (WHERE e.id IS NOT NULL) AS comptes_etudiants_trouves,
       count(*) FILTER (WHERE e.id IS NULL) AS comptes_a_creer_ou_rapprocher
FROM import_inf342_source s
LEFT JOIN gnu.etudiant e ON upper(trim(e.matricule)) = s.matricule_normalise;

SELECT s.ligne_source, s.nom_prenoms_source, s.matricule_normalise AS matricule
FROM import_inf342_source s
WHERE NOT EXISTS (
  SELECT 1 FROM gnu.etudiant e WHERE upper(trim(e.matricule)) = s.matricule_normalise
)
ORDER BY s.numero;

-- Seuls les étudiants déjà munis d'un compte sont ajoutés en brouillon.
-- L'agent devra examiner/valider ces demandes dans l'application.
INSERT INTO gnu.inscription_classe
  (etudiant_id, classe_id, statut_redoublant, statut_inscription)
SELECT e.id, c.id, false, 'BROUILLON'
FROM import_inf342_source s
JOIN gnu.etudiant e ON upper(trim(e.matricule)) = s.matricule_normalise
JOIN gnu.classe c ON c.code_classe = 'INF-L3-2025-2026'
ON CONFLICT (etudiant_id, classe_id) DO NOTHING;

COMMIT;
