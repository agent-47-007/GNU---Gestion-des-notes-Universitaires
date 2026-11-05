-- Active INF500 dans les catalogues Informatique déjà chargés.
-- INF500 est une UE officielle M2-S2 de 60 crédits sans EC dans le syllabus.

BEGIN;
SET LOCAL search_path = gnu, public;
\i docs/imports/013_regle_ue_memoire_inf500.sql

DO $$
DECLARE
  target_count integer;
BEGIN
  SELECT count(*) INTO target_count
  FROM gnu.ue u
  JOIN gnu.niveau n ON n.id = u.niveau_id AND n.code_niv = 'M2'
  JOIN gnu.filiere f ON f.id = n.filiere_id AND f.code_f = 'INF'
  WHERE u.code_ue = 'INF500'
    AND u.numero_semestre = 2
    AND u.credit_ue = 60
    AND u.statut_catalogue IN ('BROUILLON', 'ACTIF')
    AND NOT EXISTS (SELECT 1 FROM gnu.matiere m WHERE m.ue_id = u.id);

  IF target_count = 0 THEN
    RAISE EXCEPTION 'Aucune INF500 M2-S2 de 60 crédits sans EC trouvée; vérifiez le catalogue avant modification.';
  END IF;

  UPDATE gnu.ue u
  SET statut_catalogue = 'ACTIF', updated_at = statement_timestamp()
  FROM gnu.niveau n
  JOIN gnu.filiere f ON f.id = n.filiere_id AND f.code_f = 'INF'
  WHERE u.niveau_id = n.id
    AND n.code_niv = 'M2'
    AND u.code_ue = 'INF500'
    AND u.numero_semestre = 2
    AND u.credit_ue = 60
    AND u.statut_catalogue = 'BROUILLON'
    AND NOT EXISTS (SELECT 1 FROM gnu.matiere m WHERE m.ue_id = u.id);

  IF EXISTS (
    SELECT 1 FROM gnu.ue u
    JOIN gnu.niveau n ON n.id = u.niveau_id
    JOIN gnu.filiere f ON f.id = n.filiere_id AND f.code_f = 'INF'
    WHERE u.code_ue = 'INF500' AND n.code_niv = 'M2'
      AND u.numero_semestre = 2 AND u.credit_ue = 60
      AND u.statut_catalogue <> 'ACTIF'
      AND NOT EXISTS (SELECT 1 FROM gnu.matiere m WHERE m.ue_id = u.id)
  ) THEN
    RAISE EXCEPTION 'Toutes les entrées INF500 correspondantes n’ont pas été activées.';
  END IF;
END $$;

COMMIT;
