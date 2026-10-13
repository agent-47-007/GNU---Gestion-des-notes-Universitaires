-- Validation administrative des inscriptions INF-L3-2025-2026.
BEGIN;
SET LOCAL search_path = gnu, public;

DO $$
DECLARE nb_etudiants integer;
DECLARE nb_ue_actives integer;
DECLARE nb_inscriptions integer;
BEGIN
  SELECT count(*) INTO nb_etudiants
  FROM inscription_classe ic JOIN classe c ON c.id=ic.classe_id
  WHERE c.code_classe='INF-L3-2025-2026';
  IF nb_etudiants <> 35 THEN
    RAISE EXCEPTION 'Validation interrompue : % étudiants au lieu de 35', nb_etudiants;
  END IF;

  SELECT count(*) INTO nb_ue_actives
  FROM ue u JOIN classe c ON c.niveau_id=u.niveau_id
  WHERE c.code_classe='INF-L3-2025-2026' AND u.statut_catalogue='ACTIF';
  IF nb_ue_actives <> 10 THEN
    RAISE EXCEPTION 'Validation interrompue : % UE actives au lieu de 10', nb_ue_actives;
  END IF;

  SELECT count(*) INTO nb_inscriptions
  FROM inscription_ue iu
  JOIN inscription_classe ic ON ic.id=iu.inscription_classe_id
  JOIN classe c ON c.id=ic.classe_id
  WHERE c.code_classe='INF-L3-2025-2026';
  IF nb_inscriptions <> 350 THEN
    RAISE EXCEPTION 'Validation interrompue : % inscriptions UE au lieu de 350', nb_inscriptions;
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
