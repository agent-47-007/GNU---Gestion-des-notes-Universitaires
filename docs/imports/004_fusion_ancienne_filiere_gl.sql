-- GNU - GL devient une spécialité de la filière Informatique
-- Migration contrôlée : arrêt automatique en cas de conflit de données.

BEGIN;
SET LOCAL search_path = gnu, public;

DO $$
DECLARE
  old_filiere bigint;
  inf_filiere bigint;
  old_niveau record;
  target_id bigint;
  gl_specialite bigint;
BEGIN
  SELECT id INTO old_filiere FROM filiere WHERE code_f = 'GL' AND nom_f = 'Génie logiciel';
  SELECT id INTO inf_filiere FROM filiere WHERE code_f = 'INF';
  IF old_filiere IS NULL THEN
    RAISE NOTICE 'Aucune ancienne filière GL à fusionner.';
    RETURN;
  END IF;
  IF inf_filiere IS NULL THEN
    RAISE EXCEPTION 'La filière INF doit exister avant la fusion.';
  END IF;

  SELECT id INTO gl_specialite FROM specialite
  WHERE filiere_id = inf_filiere AND code_specialite = 'GL';
  IF gl_specialite IS NULL THEN
    RAISE EXCEPTION 'La spécialité INF/GL doit être créée par la migration 003.';
  END IF;

  FOR old_niveau IN SELECT id, code_niv FROM niveau WHERE filiere_id = old_filiere LOOP
    SELECT id INTO target_id FROM niveau
    WHERE filiere_id = inf_filiere AND code_niv = old_niveau.code_niv;

    IF target_id IS NULL THEN
      UPDATE niveau SET filiere_id = inf_filiere, specialite_id = gl_specialite
      WHERE id = old_niveau.id;
      CONTINUE;
    END IF;

    IF EXISTS (SELECT 1 FROM classe c WHERE c.niveau_id = old_niveau.id
      AND EXISTS (SELECT 1 FROM classe c2 WHERE c2.niveau_id = target_id AND c2.annee_id = c.annee_id)) THEN
      RAISE EXCEPTION 'Conflit de classe détecté pour le niveau %; fusion annulée.', old_niveau.code_niv;
    END IF;
    IF EXISTS (SELECT 1 FROM ue u WHERE u.niveau_id = old_niveau.id
      AND EXISTS (SELECT 1 FROM ue u2 WHERE u2.niveau_id = target_id
        AND u2.version_programme = u.version_programme AND u2.code_ue = u.code_ue)) THEN
      RAISE EXCEPTION 'Conflit d''UE détecté pour le niveau %; fusion annulée.', old_niveau.code_niv;
    END IF;

    UPDATE classe SET niveau_id = target_id WHERE niveau_id = old_niveau.id;
    UPDATE ue SET niveau_id = target_id WHERE niveau_id = old_niveau.id;
    DELETE FROM niveau WHERE id = old_niveau.id;
  END LOOP;

  DELETE FROM filiere WHERE id = old_filiere;
END $$;

COMMIT;
