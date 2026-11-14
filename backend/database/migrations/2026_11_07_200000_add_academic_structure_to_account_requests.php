<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::unprepared(<<<'SQL'
ALTER TABLE gnu.demande_compte
    ADD COLUMN IF NOT EXISTS filiere_id bigint,
    ADD COLUMN IF NOT EXISTS specialite_id bigint;

DO $migration$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint c
        JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = ANY(c.conkey)
        WHERE c.conrelid = 'gnu.demande_compte'::regclass
          AND c.confrelid = 'gnu.filiere'::regclass
          AND c.contype = 'f'
          AND a.attname = 'filiere_id'
    ) THEN
        ALTER TABLE gnu.demande_compte
            ADD CONSTRAINT demande_compte_filiere_id_foreign
            FOREIGN KEY (filiere_id) REFERENCES gnu.filiere(id) ON DELETE RESTRICT;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint c
        JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = ANY(c.conkey)
        WHERE c.conrelid = 'gnu.demande_compte'::regclass
          AND c.confrelid = 'gnu.specialite'::regclass
          AND c.contype = 'f'
          AND a.attname = 'specialite_id'
    ) THEN
        ALTER TABLE gnu.demande_compte
            ADD CONSTRAINT demande_compte_specialite_id_foreign
            FOREIGN KEY (specialite_id) REFERENCES gnu.specialite(id) ON DELETE RESTRICT;
    END IF;
END
$migration$;
SQL);
    }

    public function down(): void
    {
        DB::unprepared(<<<'SQL'
ALTER TABLE gnu.demande_compte
    DROP CONSTRAINT IF EXISTS demande_compte_filiere_id_foreign,
    DROP CONSTRAINT IF EXISTS demande_compte_specialite_id_foreign,
    DROP COLUMN IF EXISTS filiere_id,
    DROP COLUMN IF EXISTS specialite_id;
SQL);
    }
};
