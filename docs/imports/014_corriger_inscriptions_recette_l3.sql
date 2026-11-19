-- Corrige les inscriptions créées par l'ancien import qui inscrivait chaque
-- étudiant aux 18 UE actives. Réservé à la base locale gnu_notes_recette.
-- Conserve les 6 UE de référence par semestre pour les 35 étudiants L3.

BEGIN;
SET LOCAL search_path = gnu, public;

DO $$
DECLARE
  nb_etudiants integer;
BEGIN
  IF current_database() <> 'gnu_notes_recette' THEN
    RAISE EXCEPTION 'Script réservé à la base locale gnu_notes_recette (base courante : %)', current_database();
  END IF;

  SELECT count(*) INTO nb_etudiants
  FROM inscription_classe ic
  JOIN classe c ON c.id = ic.classe_id
  WHERE c.code_classe = 'INF-L3-2025-2026';

  IF nb_etudiants <> 35 THEN
    RAISE EXCEPTION 'Correction interrompue : % inscriptions de classe trouvées au lieu de 35', nb_etudiants;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM inscription_classe ic
    JOIN classe c ON c.id = ic.classe_id
    JOIN inscription_ue iu ON iu.inscription_classe_id = ic.id
    JOIN ue u ON u.id = iu.ue_id
    WHERE c.code_classe = 'INF-L3-2025-2026'
      AND u.code_ue NOT IN (
        'INF311', 'INF321', 'INF331', 'INF341', 'INF361', 'FBL311',
        'INF312', 'INF322', 'INF332', 'INF342', 'INF362', 'PPE312'
      )
      AND iu.statut_inscription <> 'BROUILLON'
  ) THEN
    RAISE EXCEPTION 'Correction interrompue : une UE hors sélection est déjà validée ou annulée';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM note no
    JOIN inscription_ue iu ON iu.id = no.inscription_ue_id
    JOIN inscription_classe ic ON ic.id = iu.inscription_classe_id
    JOIN classe c ON c.id = ic.classe_id
    JOIN ue u ON u.id = iu.ue_id
    WHERE c.code_classe = 'INF-L3-2025-2026'
      AND u.code_ue NOT IN (
        'INF311', 'INF321', 'INF331', 'INF341', 'INF361', 'FBL311',
        'INF312', 'INF322', 'INF332', 'INF342', 'INF362', 'PPE312'
      )
  ) THEN
    RAISE EXCEPTION 'Correction interrompue : des notes existent déjà sur les UE hors sélection';
  END IF;
END $$;

DELETE FROM inscription_ue iu
USING inscription_classe ic, classe c, ue u
WHERE iu.inscription_classe_id = ic.id
  AND ic.classe_id = c.id
  AND u.id = iu.ue_id
  AND c.code_classe = 'INF-L3-2025-2026'
  AND u.code_ue NOT IN (
    'INF311', 'INF321', 'INF331', 'INF341', 'INF361', 'FBL311',
    'INF312', 'INF322', 'INF332', 'INF342', 'INF362', 'PPE312'
  );

COMMIT;
