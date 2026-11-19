-- Validation administrative des inscriptions INF-L3-2025-2026.
BEGIN;
SET LOCAL search_path = gnu, public;

DO $$
DECLARE nb_etudiants integer;
DECLARE nb_inscriptions integer;
DECLARE inscriptions_mal_reparties integer;
BEGIN
  SELECT count(*) INTO nb_etudiants
  FROM inscription_classe ic JOIN classe c ON c.id=ic.classe_id
  WHERE c.code_classe='INF-L3-2025-2026';
  IF nb_etudiants <> 35 THEN
    RAISE EXCEPTION 'Validation interrompue : % étudiants au lieu de 35', nb_etudiants;
  END IF;

  SELECT count(*) INTO nb_inscriptions
  FROM inscription_ue iu
  JOIN inscription_classe ic ON ic.id=iu.inscription_classe_id
  JOIN classe c ON c.id=ic.classe_id
  WHERE c.code_classe='INF-L3-2025-2026';
  IF nb_inscriptions <> 420 THEN
    RAISE EXCEPTION 'Validation interrompue : % inscriptions UE au lieu de 420 (12 par étudiant)', nb_inscriptions;
  END IF;

  SELECT count(*) INTO inscriptions_mal_reparties
  FROM (
    SELECT ic.id
    FROM inscription_classe ic
    JOIN classe c ON c.id=ic.classe_id
    LEFT JOIN inscription_ue iu ON iu.inscription_classe_id=ic.id
    LEFT JOIN ue u ON u.id=iu.ue_id
    WHERE c.code_classe='INF-L3-2025-2026'
    GROUP BY ic.id
    HAVING count(iu.id) FILTER (WHERE u.numero_semestre=1) <> 6
        OR count(iu.id) FILTER (WHERE u.numero_semestre=2) <> 6
  ) incorrect;
  IF inscriptions_mal_reparties <> 0 THEN
    RAISE EXCEPTION 'Validation interrompue : % étudiant(s) n’ont pas exactement 6 UE dans chaque semestre', inscriptions_mal_reparties;
  END IF;
END $$;

UPDATE inscription_classe ic
SET statut_inscription='VALIDEE', updated_at=statement_timestamp()
FROM classe c
WHERE c.id=ic.classe_id AND c.code_classe='INF-L3-2025-2026';

UPDATE inscription_ue iu
SET statut_inscription='VALIDEE', updated_at=statement_timestamp()
FROM inscription_classe ic
JOIN classe c ON c.id=ic.classe_id
WHERE iu.inscription_classe_id=ic.id AND c.code_classe='INF-L3-2025-2026';

COMMIT;
