-- Conservation des contrôles du catalogue et exception officielle pour INF500.
-- Exécuter avec le propriétaire de gnu.controle_catalogue (généralement postgres).

CREATE OR REPLACE FUNCTION gnu.controle_catalogue()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'gnu', 'pg_catalog'
AS $function$
DECLARE
  u ue;
  nb integer;
BEGIN
  IF TG_TABLE_NAME = 'ue' THEN
    IF TG_OP = 'UPDATE' AND OLD.statut_catalogue <> 'BROUILLON' THEN
      PERFORM exiger(
        (to_jsonb(NEW) - 'statut_catalogue' - 'updated_at') = (to_jsonb(OLD) - 'statut_catalogue' - 'updated_at'),
        'Créer une version de programme au lieu de modifier cette UE'
      );
      PERFORM exiger(NEW.statut_catalogue <> 'BROUILLON', 'Catalogue archivé non réouvrable');
    END IF;

    IF NEW.statut_catalogue = 'ACTIF' THEN
      SELECT count(*) INTO nb FROM matiere WHERE ue_id = NEW.id;
      PERFORM exiger(
        nb BETWEEN 1 AND 2
          OR (
            nb = 0
            AND NEW.code_ue = 'INF500'
            AND NEW.numero_semestre = 2
            AND NEW.credit_ue = 60
            AND EXISTS (
              SELECT 1
              FROM niveau n
              JOIN filiere f ON f.id = n.filiere_id AND f.code_f = 'INF'
              WHERE n.id = NEW.niveau_id AND n.code_niv = 'M2'
            )
          ),
        'Une UE active doit comporter un ou deux EC, sauf INF500 (UE de mémoire M2-S2 sans EC)'
      );
    END IF;
  ELSE
    SELECT * INTO u FROM ue
    WHERE id = CASE WHEN TG_OP = 'DELETE' THEN OLD.ue_id ELSE NEW.ue_id END
    FOR UPDATE;
    PERFORM exiger(u.statut_catalogue = 'BROUILLON', 'Les EC d’une UE activée sont immuables');
    IF TG_OP <> 'DELETE' THEN
      PERFORM id FROM niveau WHERE id = u.niveau_id FOR UPDATE;
      PERFORM exiger(
        NOT EXISTS (
          SELECT 1 FROM matiere mm
          JOIN ue uu ON uu.id = mm.ue_id
          WHERE uu.niveau_id = u.niveau_id
            AND uu.version_programme = u.version_programme
            AND mm.code_m = NEW.code_m
            AND mm.id <> NEW.id
        ),
        'Code EC déjà utilisé dans cette version du niveau'
      );
    END IF;
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END
$function$;
