<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        if (DB::getDriverName() !== 'pgsql') {
            throw new RuntimeException('Cette migration doit être exécutée sur PostgreSQL.');
        }

        $column = DB::selectOne("SELECT data_type, udt_schema, udt_name FROM information_schema.columns WHERE table_schema = 'gnu' AND table_name = 'evaluation' AND column_name = 'type_eval'");
        if ($column === null) {
            throw new RuntimeException('La colonne gnu.evaluation.type_eval est introuvable.');
        }

        if ($column->data_type === 'USER-DEFINED') {
            $isEnum = DB::scalar(
                'SELECT typtype = ? FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace WHERE n.nspname = ? AND t.typname = ?',
                ['e', $column->udt_schema, $column->udt_name],
            );
            if (! filter_var($isEnum, FILTER_VALIDATE_BOOLEAN)) {
                throw new RuntimeException('Le type personnalisé de evaluation.type_eval doit être examiné avant d’y ajouter TPE.');
            }

            $schema = DB::selectOne('SELECT quote_ident(?) AS value', [$column->udt_schema])->value;
            $type = DB::selectOne('SELECT quote_ident(?) AS value', [$column->udt_name])->value;
            DB::statement("ALTER TYPE {$schema}.{$type} ADD VALUE IF NOT EXISTS 'TPE'");

            return;
        }

        if (! in_array($column->data_type, ['character varying', 'character', 'text'], true)) {
            throw new RuntimeException('Le type SQL de evaluation.type_eval ne peut pas accepter TPE sans adaptation manuelle.');
        }

        $checks = DB::select("SELECT conname, pg_get_constraintdef(oid) AS definition FROM pg_constraint WHERE conrelid = 'gnu.evaluation'::regclass AND contype = 'c' AND pg_get_constraintdef(oid) ILIKE '%type_eval%'");
        $hasAllowedTypes = false;
        foreach ($checks as $check) {
            $definition = $check->definition;
            if (! str_contains($definition, "'CC'") || ! str_contains($definition, "'TP'") || ! str_contains($definition, "'SN'")) {
                continue;
            }
            $hasAllowedTypes = true;
            if (str_contains($definition, "'TPE'")) {
                continue;
            }
            $updated = str_replace("'SN'", "'SN', 'TPE'", $definition);
            if ($updated === $definition) {
                throw new RuntimeException('Impossible d’étendre automatiquement la contrainte de type_eval.');
            }
            $name = DB::selectOne('SELECT quote_ident(?) AS value', [$check->conname])->value;
            DB::statement("ALTER TABLE gnu.evaluation DROP CONSTRAINT {$name}");
            DB::statement("ALTER TABLE gnu.evaluation ADD CONSTRAINT {$name} {$updated}");
        }

        if (! $hasAllowedTypes) {
            DB::statement("ALTER TABLE gnu.evaluation ADD CONSTRAINT evaluation_type_eval_official_check CHECK (type_eval IN ('CC', 'TP', 'TPE', 'SN'))");
        }
    }

    public function down(): void
    {
        throw new RuntimeException('La prise en charge de TPE fait partie du référentiel officiel et ne peut être supprimée automatiquement.');
    }
};
