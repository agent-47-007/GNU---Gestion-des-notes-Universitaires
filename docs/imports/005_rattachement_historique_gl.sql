-- GNU - rattachement historique de l'ancienne filière GL
-- Ne modifie aucun niveau_id et respecte le trigger d'immuabilité.

BEGIN;
SET LOCAL search_path = gnu, public;

ALTER TABLE classe
  ADD COLUMN IF NOT EXISTS specialite_id bigint REFERENCES specialite(id);

UPDATE niveau n
SET specialite_id = s.id,
    updated_at = statement_timestamp()
FROM specialite s
WHERE n.filiere_id = (SELECT id FROM filiere WHERE code_f = 'GL' AND nom_f = 'Génie logiciel')
  AND s.filiere_id = (SELECT id FROM filiere WHERE code_f = 'INF')
  AND s.code_specialite = 'GL'
  AND n.specialite_id IS NULL;

UPDATE classe c
SET specialite_id = n.specialite_id,
    updated_at = statement_timestamp()
FROM niveau n
WHERE c.niveau_id = n.id
  AND n.specialite_id IS NOT NULL
  AND c.specialite_id IS NULL;

COMMIT;
