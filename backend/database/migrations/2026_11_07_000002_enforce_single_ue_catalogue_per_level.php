<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        $resetRole = $this->switchToCatalogueOwner();
        try {
            $this->consolidateCatalogue();
        } finally {
            if ($resetRole) {
                DB::statement('RESET ROLE');
            }
        }
    }

    private function consolidateCatalogue(): void
    {
        if (DB::table('gnu.classe')->where('version_programme', '<>', 1)->exists()) {
            throw new RuntimeException('Des classes utilisent un catalogue différent du catalogue unique. Vérifiez leurs inscriptions avant la consolidation.');
        }

        DB::statement(<<<'SQL'
            CREATE TEMP TABLE gnu_catalogue_latest ON COMMIT DROP AS
            SELECT DISTINCT ON (source.niveau_id, source.code_ue)
                source.id AS source_id,
                COALESCE(canonical.id, source.id) AS canonical_id,
                source.version_programme AS source_version,
                source.niveau_id,
                source.code_ue,
                source.intitule_ue,
                source.numero_semestre,
                source.categorie_ue,
                source.credit_ue,
                source.statut_catalogue,
                source.created_at,
                source.updated_at
            FROM gnu.ue source
            LEFT JOIN gnu.ue canonical
              ON canonical.niveau_id = source.niveau_id
             AND canonical.code_ue = source.code_ue
             AND canonical.version_programme = 1
            WHERE source.version_programme <> 1
            ORDER BY source.niveau_id, source.code_ue,
                     source.version_programme DESC, source.id DESC
            SQL);

        DB::statement(<<<'SQL'
            CREATE TEMP TABLE gnu_catalogue_map ON COMMIT DROP AS
            SELECT old.id AS old_id,
                   latest.canonical_id,
                   latest.source_id,
                   latest.source_version,
                   old.version_programme AS old_version
            FROM gnu.ue old
            JOIN pg_temp.gnu_catalogue_latest latest
              ON latest.niveau_id = old.niveau_id
             AND latest.code_ue = old.code_ue
            WHERE old.version_programme <> 1
            SQL);

        DB::statement(<<<'SQL'
            CREATE TEMP TABLE gnu_catalogue_replacements ON COMMIT DROP AS
            SELECT * FROM pg_temp.gnu_catalogue_latest
            WHERE canonical_id <> source_id
            SQL);

        DB::statement(<<<'SQL'
            CREATE TEMP TABLE gnu_catalogue_source_ec ON COMMIT DROP AS
            SELECT replacement.canonical_id,
                   source.code_m,
                   source.intitule_matiere,
                   source.rang_ec,
                   source.credit_matiere,
                   source.created_at,
                   source.updated_at
            FROM pg_temp.gnu_catalogue_replacements replacement
            JOIN gnu.matiere source ON source.ue_id = replacement.source_id
            SQL);

        DB::statement(<<<'SQL'
            CREATE TEMP TABLE gnu_catalogue_delete_ec ON COMMIT DROP AS
            SELECT source_ec.id
            FROM gnu.matiere source_ec
            JOIN pg_temp.gnu_catalogue_map map ON map.old_id = source_ec.ue_id
            WHERE map.old_id <> map.canonical_id
            UNION
            SELECT existing_ec.id
            FROM gnu.matiere existing_ec
            JOIN pg_temp.gnu_catalogue_replacements replacement
              ON replacement.canonical_id = existing_ec.ue_id
            WHERE NOT EXISTS (
                SELECT 1 FROM pg_temp.gnu_catalogue_source_ec source_ec
                WHERE source_ec.canonical_id = existing_ec.ue_id
                  AND source_ec.rang_ec = existing_ec.rang_ec
            )
            SQL);

        $this->assertNoForeignReferencesToNoncanonicalUnits();
        $this->assertNoForeignReferencesToRemovedElements();
        $this->mergeEvaluationProfiles();
        $this->disableCatalogueGuards();

        DB::statement(<<<'SQL'
            DELETE FROM gnu.matiere element
            USING pg_temp.gnu_catalogue_delete_ec removed
            WHERE element.id = removed.id
            SQL);

        // Free old EC codes first, then retain each canonical row ID by EC rank.
        DB::statement(<<<'SQL'
            UPDATE gnu.matiere target
            SET code_m = 'TMP' || target.id::text
            FROM pg_temp.gnu_catalogue_source_ec source
            WHERE target.ue_id = source.canonical_id
              AND target.rang_ec = source.rang_ec
              AND target.code_m <> source.code_m
            SQL);

        DB::statement(<<<'SQL'
            UPDATE gnu.matiere target
            SET code_m = source.code_m,
                intitule_matiere = source.intitule_matiere,
                credit_matiere = source.credit_matiere,
                updated_at = statement_timestamp()
            FROM pg_temp.gnu_catalogue_source_ec source
            WHERE target.ue_id = source.canonical_id
              AND target.rang_ec = source.rang_ec
            SQL);

        DB::statement(<<<'SQL'
            INSERT INTO gnu.matiere (
                code_m, intitule_matiere, ue_id, rang_ec, credit_matiere, created_at, updated_at
            )
            SELECT source.code_m, source.intitule_matiere, source.canonical_id,
                   source.rang_ec, source.credit_matiere,
                   source.created_at, statement_timestamp()
            FROM pg_temp.gnu_catalogue_source_ec source
            WHERE NOT EXISTS (
                SELECT 1 FROM gnu.matiere target
                WHERE target.ue_id = source.canonical_id
                  AND target.rang_ec = source.rang_ec
            )
            SQL);

        DB::statement(<<<'SQL'
            UPDATE gnu.ue target
            SET intitule_ue = source.intitule_ue,
                numero_semestre = source.numero_semestre,
                categorie_ue = source.categorie_ue,
                credit_ue = source.credit_ue,
                statut_catalogue = source.statut_catalogue,
                updated_at = statement_timestamp()
            FROM pg_temp.gnu_catalogue_replacements source
            WHERE target.id = source.canonical_id
            SQL);

        DB::statement(<<<'SQL'
            DELETE FROM gnu.ue old
            USING pg_temp.gnu_catalogue_map map
            WHERE old.id = map.old_id
              AND map.old_id <> map.canonical_id
            SQL);

        DB::table('gnu.ue')->where('version_programme', '<>', 1)->update([
            'version_programme' => 1,
            'updated_at' => DB::raw('statement_timestamp()'),
        ]);

        $this->enableCatalogueGuards();
        $this->installReplaceInPlaceCatalogueRule();

        $duplicateUes = DB::table('gnu.ue')->select('niveau_id', 'code_ue')
            ->groupBy('niveau_id', 'code_ue')->havingRaw('count(*) > 1')->exists();
        if ($duplicateUes) {
            throw new RuntimeException('Des codes UE restent dupliqués dans un même niveau après consolidation.');
        }

        $duplicateElements = DB::table('gnu.matiere as m')
            ->join('gnu.ue as u', 'u.id', '=', 'm.ue_id')
            ->select('u.niveau_id', 'm.code_m')
            ->groupBy('u.niveau_id', 'm.code_m')
            ->havingRaw('count(*) > 1')->exists();
        if ($duplicateElements) {
            throw new RuntimeException('Des codes EC restent dupliqués dans un même niveau après consolidation.');
        }

        DB::statement('CREATE UNIQUE INDEX IF NOT EXISTS ue_niveau_code_ue_unique ON gnu.ue (niveau_id, code_ue)');
        DB::statement(<<<'SQL'
            DO $constraints$
            BEGIN
                IF NOT EXISTS (
                    SELECT 1 FROM pg_constraint
                    WHERE conrelid = 'gnu.ue'::regclass
                      AND conname = 'ue_version_programme_unique'
                ) THEN
                    ALTER TABLE gnu.ue
                    ADD CONSTRAINT ue_version_programme_unique CHECK (version_programme = 1);
                END IF;
                IF NOT EXISTS (
                    SELECT 1 FROM pg_constraint
                    WHERE conrelid = 'gnu.classe'::regclass
                      AND conname = 'classe_version_programme_unique'
                ) THEN
                    ALTER TABLE gnu.classe
                    ADD CONSTRAINT classe_version_programme_unique CHECK (version_programme = 1);
                END IF;
            END
            $constraints$
            SQL);
    }

    public function down(): void
    {
        $resetRole = $this->switchToCatalogueOwner();
        try {
            DB::statement('ALTER TABLE gnu.classe DROP CONSTRAINT IF EXISTS classe_version_programme_unique');
            DB::statement('ALTER TABLE gnu.ue DROP CONSTRAINT IF EXISTS ue_version_programme_unique');
            DB::statement('DROP INDEX IF EXISTS gnu.ue_niveau_code_ue_unique');
        } finally {
            if ($resetRole) {
                DB::statement('RESET ROLE');
            }
        }
    }

    private function switchToCatalogueOwner(): bool
    {
        $owners = DB::select(<<<'SQL'
            SELECT DISTINCT owner_role.rolname
            FROM (
                SELECT relation.relowner AS owner_id
                FROM pg_class relation
                JOIN pg_namespace relation_schema ON relation_schema.oid = relation.relnamespace
                WHERE relation_schema.nspname = 'gnu'
                  AND relation.relname IN ('ue', 'matiere', 'classe')
                UNION
                SELECT routine.proowner AS owner_id
                FROM pg_proc routine
                JOIN pg_namespace routine_schema ON routine_schema.oid = routine.pronamespace
                WHERE routine_schema.nspname = 'gnu'
                  AND routine.proname = 'controle_catalogue'
                  AND pg_get_function_identity_arguments(routine.oid) = ''
            ) objects
            JOIN pg_roles owner_role ON owner_role.oid = objects.owner_id
            ORDER BY owner_role.rolname
            SQL);

        if ($owners === []) {
            throw new RuntimeException('Impossible de déterminer les propriétaires des tables du catalogue GNU.');
        }
        if (count($owners) > 1) {
            throw new RuntimeException('Les tables du catalogue GNU ont plusieurs propriétaires. Exécutez la migration avec un rôle propriétaire commun.');
        }

        $owner = (string) $owners[0]->rolname;
        $current = (string) DB::selectOne('SELECT current_user AS role_name')->role_name;
        if ($current === $owner) {
            return false;
        }

        $membership = DB::selectOne("SELECT pg_has_role(current_user, ?::name, 'SET') AS can_set_role", [$owner]);
        $canSetRole = in_array(strtolower((string) $membership->can_set_role), ['1', 't', 'true'], true);
        if (! $canSetRole) {
            throw new RuntimeException("Le rôle de migration « {$current} » ne peut pas prendre le rôle propriétaire « {$owner} ». Accordez ce rôle au compte de migration puis relancez.");
        }

        $statement = DB::selectOne("SELECT format('SET ROLE %I', ?::name) AS sql_statement", [$owner])->sql_statement;
        DB::unprepared((string) $statement);

        return true;
    }

    private function assertNoForeignReferencesToNoncanonicalUnits(): void
    {
        DB::statement(<<<'SQL'
            DO $references$
            DECLARE fk record; found_reference boolean;
            BEGIN
                FOR fk IN
                    SELECT c.conrelid::regclass AS relation_name,
                           a.attname AS column_name,
                           array_length(c.conkey, 1) AS column_count
                    FROM pg_constraint c
                    JOIN LATERAL unnest(c.conkey) key(attnum) ON true
                    JOIN pg_attribute a
                      ON a.attrelid = c.conrelid AND a.attnum = key.attnum
                    WHERE c.contype = 'f'
                      AND c.confrelid = 'gnu.ue'::regclass
                LOOP
                    IF fk.relation_name IN (
                        'gnu.matiere'::regclass,
                        'gnu.profil_evaluation_ue'::regclass
                    ) THEN
                        CONTINUE;
                    END IF;
                    IF fk.column_count <> 1 THEN
                        RAISE EXCEPTION 'Référence composée vers gnu.ue dans % : consolidation interrompue pour contrôle manuel.', fk.relation_name;
                    END IF;
                    EXECUTE format(
                        'SELECT EXISTS (SELECT 1 FROM %s WHERE %I IN (SELECT old_id FROM pg_temp.gnu_catalogue_map WHERE old_id <> canonical_id))',
                        fk.relation_name, fk.column_name
                    ) INTO found_reference;
                    IF found_reference THEN
                        RAISE EXCEPTION 'Des données de % utilisent encore une UE à fusionner. Aucune ligne n’a été supprimée.', fk.relation_name;
                    END IF;
                END LOOP;
            END
            $references$
            SQL);
    }

    private function assertNoForeignReferencesToRemovedElements(): void
    {
        DB::statement(<<<'SQL'
            DO $references$
            DECLARE fk record; found_reference boolean;
            BEGIN
                FOR fk IN
                    SELECT c.conrelid::regclass AS relation_name,
                           a.attname AS column_name,
                           array_length(c.conkey, 1) AS column_count
                    FROM pg_constraint c
                    JOIN LATERAL unnest(c.conkey) key(attnum) ON true
                    JOIN pg_attribute a
                      ON a.attrelid = c.conrelid AND a.attnum = key.attnum
                    WHERE c.contype = 'f'
                      AND c.confrelid = 'gnu.matiere'::regclass
                LOOP
                    IF fk.column_count <> 1 THEN
                        RAISE EXCEPTION 'Référence composée vers gnu.matiere dans % : consolidation interrompue pour contrôle manuel.', fk.relation_name;
                    END IF;
                    EXECUTE format(
                        'SELECT EXISTS (SELECT 1 FROM %s WHERE %I IN (SELECT id FROM pg_temp.gnu_catalogue_delete_ec))',
                        fk.relation_name, fk.column_name
                    ) INTO found_reference;
                    IF found_reference THEN
                        RAISE EXCEPTION 'Des affectations, notes ou requêtes de % utilisent un EC à remplacer. Aucune ligne n’a été supprimée.', fk.relation_name;
                    END IF;
                END LOOP;
            END
            $references$
            SQL);
    }

    private function mergeEvaluationProfiles(): void
    {
        DB::statement(<<<'SQL'
            CREATE TEMP TABLE gnu_catalogue_profile_source ON COMMIT DROP AS
            SELECT DISTINCT ON (map.canonical_id)
                   map.canonical_id,
                   profile.code_profil,
                   profile.configure_par,
                   profile.created_at,
                   profile.updated_at
            FROM pg_temp.gnu_catalogue_map map
            JOIN gnu.profil_evaluation_ue profile ON profile.ue_id = map.old_id
            ORDER BY map.canonical_id, map.old_version DESC, map.old_id DESC
            SQL);

        DB::statement(<<<'SQL'
            UPDATE gnu.profil_evaluation_ue target
            SET code_profil = source.code_profil,
                configure_par = source.configure_par,
                updated_at = statement_timestamp()
            FROM pg_temp.gnu_catalogue_profile_source source
            WHERE target.ue_id = source.canonical_id
            SQL);

        DB::statement(<<<'SQL'
            INSERT INTO gnu.profil_evaluation_ue (
                ue_id, code_profil, configure_par, created_at, updated_at
            )
            SELECT source.canonical_id, source.code_profil, source.configure_par,
                   source.created_at, source.updated_at
            FROM pg_temp.gnu_catalogue_profile_source source
            WHERE NOT EXISTS (
                SELECT 1 FROM gnu.profil_evaluation_ue target
                WHERE target.ue_id = source.canonical_id
            )
            SQL);

        DB::statement(<<<'SQL'
            DELETE FROM gnu.profil_evaluation_ue profile
            USING pg_temp.gnu_catalogue_map map
            WHERE profile.ue_id = map.old_id
              AND map.old_id <> map.canonical_id
            SQL);
    }

    private function disableCatalogueGuards(): void
    {
        DB::statement(<<<'SQL'
            DO $triggers$
            DECLARE trigger_row record;
            BEGIN
                FOR trigger_row IN
                    SELECT relation.oid::regclass AS relation_name,
                           t.tgname AS trigger_name
                    FROM pg_trigger t
                    JOIN pg_class relation ON relation.oid = t.tgrelid
                    JOIN pg_proc routine ON routine.oid = t.tgfoid
                    JOIN pg_namespace routine_schema ON routine_schema.oid = routine.pronamespace
                    WHERE NOT t.tgisinternal
                      AND relation.oid IN ('gnu.ue'::regclass, 'gnu.matiere'::regclass)
                      AND routine_schema.nspname = 'gnu'
                      AND routine.proname = 'controle_catalogue'
                LOOP
                    EXECUTE format('ALTER TABLE %s DISABLE TRIGGER %I', trigger_row.relation_name, trigger_row.trigger_name);
                END LOOP;
            END
            $triggers$
            SQL);
    }

    private function enableCatalogueGuards(): void
    {
        DB::statement(<<<'SQL'
            DO $triggers$
            DECLARE trigger_row record;
            BEGIN
                FOR trigger_row IN
                    SELECT relation.oid::regclass AS relation_name,
                           t.tgname AS trigger_name
                    FROM pg_trigger t
                    JOIN pg_class relation ON relation.oid = t.tgrelid
                    JOIN pg_proc routine ON routine.oid = t.tgfoid
                    JOIN pg_namespace routine_schema ON routine_schema.oid = routine.pronamespace
                    WHERE NOT t.tgisinternal
                      AND relation.oid IN ('gnu.ue'::regclass, 'gnu.matiere'::regclass)
                      AND routine_schema.nspname = 'gnu'
                      AND routine.proname = 'controle_catalogue'
                LOOP
                    EXECUTE format('ALTER TABLE %s ENABLE TRIGGER %I', trigger_row.relation_name, trigger_row.trigger_name);
                END LOOP;
            END
            $triggers$
            SQL);
    }

    private function installReplaceInPlaceCatalogueRule(): void
    {
        if (DB::selectOne("SELECT to_regprocedure('gnu.controle_catalogue()') AS function_name")->function_name === null) {
            return;
        }

        DB::statement(<<<'SQL'
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
                                      SELECT 1 FROM niveau n
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
                    IF TG_OP <> 'DELETE' THEN
                        PERFORM id FROM niveau WHERE id = u.niveau_id FOR UPDATE;
                        PERFORM exiger(
                            NOT EXISTS (
                                SELECT 1 FROM matiere mm
                                JOIN ue uu ON uu.id = mm.ue_id
                                WHERE uu.niveau_id = u.niveau_id
                                  AND mm.code_m = NEW.code_m
                                  AND mm.id <> NEW.id
                            ),
                            'Code EC déjà utilisé dans le catalogue de ce niveau'
                        );
                    END IF;
                END IF;

                IF TG_OP = 'DELETE' THEN
                    RETURN OLD;
                END IF;
                RETURN NEW;
            END
            $function$
            SQL);
    }
};
