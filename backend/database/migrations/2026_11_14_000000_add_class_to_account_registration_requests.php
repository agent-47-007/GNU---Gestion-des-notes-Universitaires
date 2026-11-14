<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::unprepared(<<<'SQL'
ALTER TABLE gnu.demande_compte
    ADD COLUMN IF NOT EXISTS classe_id bigint;

DO $migration$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint c
        JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = ANY(c.conkey)
        WHERE c.conrelid = 'gnu.demande_compte'::regclass
          AND c.confrelid = 'gnu.classe'::regclass
          AND c.contype = 'f'
          AND a.attname = 'classe_id'
    ) THEN
        ALTER TABLE gnu.demande_compte
            ADD CONSTRAINT demande_compte_classe_id_foreign
            FOREIGN KEY (classe_id) REFERENCES gnu.classe(id) ON DELETE RESTRICT;
    END IF;
END
$migration$;
SQL);
    }

    public function down(): void
    {
        DB::unprepared(<<<'SQL'
ALTER TABLE gnu.demande_compte
    DROP CONSTRAINT IF EXISTS demande_compte_classe_id_foreign,
    DROP COLUMN IF EXISTS classe_id;
SQL);
    }
};
