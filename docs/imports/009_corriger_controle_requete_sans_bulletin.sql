BEGIN;
SET LOCAL search_path = gnu, pg_catalog;

CREATE OR REPLACE FUNCTION gnu.controle_requete()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'gnu', 'pg_catalog'
AS $function$
DECLARE
    ci contexte_inscription;
    b bulletin;
    pub publication;
    oldb bulletin;
    e contexte_evaluation;
    ns jsonb;
    os jsonb;
    cible bigint;
BEGIN
    SELECT * INTO ci FROM contexte_inscription WHERE inscription_ue_id = NEW.inscription_ue_id;

    IF NEW.matiere_id IS NOT NULL THEN
        PERFORM exiger(
            EXISTS (SELECT 1 FROM matiere WHERE id = NEW.matiere_id AND ue_id = ci.ue_id),
            'Requête hors UE'
        );
    ELSE
        PERFORM exiger(
            NEW.type_requete NOT IN ('ABSENCE', 'CONTESTATION', 'NOTE_MANQUANTE', 'REEVALUATION'),
            'Un élément constitutif est requis pour ce type de requête'
        );
    END IF;

    IF NEW.bulletin_conteste_id IS NOT NULL THEN
        SELECT * INTO b FROM bulletin WHERE id = NEW.bulletin_conteste_id;
        SELECT * INTO pub FROM publication WHERE id = b.publication_id;
        PERFORM exiger(
            b.id IS NOT NULL
            AND b.inscription_classe_id = ci.inscription_classe_id
            AND NEW.matiere_id IS NOT NULL
            AND EXISTS (SELECT 1 FROM matiere WHERE id = NEW.matiere_id AND ue_id = ci.ue_id),
            'Requête hors bulletin/UE'
        );
        PERFORM exiger(NEW.type_requete = 'CONTESTATION', 'Seule une contestation peut viser un bulletin');
    ELSE
        PERFORM exiger(NEW.type_requete <> 'CONTESTATION', 'Une contestation de note doit viser un bulletin publié');
    END IF;

    IF NEW.evaluation_id IS NOT NULL THEN
        SELECT * INTO e FROM contexte_evaluation WHERE id = NEW.evaluation_id;
        PERFORM exiger(e.matiere_id = NEW.matiere_id AND e.classe_id = ci.classe_id, 'Évaluation étrangère à la requête');
    END IF;

    IF NEW.note_id IS NOT NULL THEN
        PERFORM exiger(
            EXISTS (
                SELECT 1 FROM note n
                JOIN contexte_evaluation ev ON ev.id = n.evaluation_id
                WHERE n.id = NEW.note_id AND n.inscription_ue_id = NEW.inscription_ue_id
                    AND ev.matiere_id = NEW.matiere_id
                    AND (NEW.evaluation_id IS NULL OR n.evaluation_id = NEW.evaluation_id)
            ),
            'Note étrangère à la requête'
        );
    END IF;

    IF TG_OP = 'INSERT' THEN
        PERFORM exiger(
            EXISTS (
                SELECT 1 FROM etudiant et
                JOIN utilisateur us ON us.id = et.utilisateur_id
                WHERE et.id = ci.etudiant_id AND us.id = acteur() AND us.actif
            ),
            'La requête doit être soumise par l’étudiant concerné'
        );
        NEW.date_soumission := statement_timestamp();

        IF NEW.bulletin_conteste_id IS NOT NULL THEN
            PERFORM exiger(requete_dans_delai(pub.date_publication, NEW.date_soumission), 'Délai de requête de 48 h dépassé');

            IF pub.publication_precedente_id IS NOT NULL THEN
                SELECT * INTO oldb FROM bulletin
                WHERE publication_id = pub.publication_precedente_id
                    AND inscription_classe_id = ci.inscription_classe_id;
                SELECT ec INTO ns FROM jsonb_array_elements(b.contenu_fige->'ues') u
                    CROSS JOIN LATERAL jsonb_array_elements(u->'ecs') ec
                    WHERE (ec->>'matiere_id')::bigint = NEW.matiere_id;
                SELECT ec INTO os FROM jsonb_array_elements(oldb.contenu_fige->'ues') u
                    CROSS JOIN LATERAL jsonb_array_elements(u->'ecs') ec
                    WHERE (ec->>'matiere_id')::bigint = NEW.matiere_id;

                IF NEW.note_id IS NOT NULL OR NEW.evaluation_id IS NOT NULL THEN
                    SELECT coalesce(ev.evaluation_origine_id, ev.id) INTO cible
                    FROM evaluation ev
                    WHERE ev.id = coalesce(NEW.evaluation_id, (SELECT evaluation_id FROM note WHERE id = NEW.note_id));
                    SELECT value INTO ns FROM jsonb_array_elements(ns->'sources') WHERE (value->>'evaluation_origine_id')::bigint = cible;
                    SELECT value INTO os FROM jsonb_array_elements(os->'sources') WHERE (value->>'evaluation_origine_id')::bigint = cible;
                END IF;

                PERFORM exiger(ns IS NOT NULL AND ns IS DISTINCT FROM os, 'La republication ne corrige pas cette note ou cet EC');
            END IF;
        END IF;
    ELSE
        PERFORM exiger(
            EXISTS (
                SELECT 1 FROM affectation af
                JOIN enseignant en ON en.id = af.enseignant_id
                WHERE af.actif AND af.classe_id = ci.classe_id AND af.matiere_id = NEW.matiere_id
                    AND en.utilisateur_id = acteur()
            ),
            'Traitement réservé à l’enseignant'
        );
        PERFORM exiger(
            (to_jsonb(NEW)-'statut_requete'-'updated_at') = (to_jsonb(OLD)-'statut_requete'-'updated_at'),
            'Contenu d’une requête soumise immuable'
        );
    END IF;

    RETURN NEW;
END
$function$;

COMMIT;
