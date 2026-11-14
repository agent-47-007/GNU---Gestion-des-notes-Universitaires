<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::unprepared(<<<'SQL'
ALTER TABLE gnu.utilisateur
    ADD COLUMN IF NOT EXISTS supprime_le timestamptz,
    ADD COLUMN IF NOT EXISTS supprime_par bigint,
    ADD COLUMN IF NOT EXISTS motif_suppression text;

DO $migration$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'gnu.utilisateur'::regclass
          AND conname = 'utilisateur_supprime_par_foreign'
    ) THEN
        ALTER TABLE gnu.utilisateur
            ADD CONSTRAINT utilisateur_supprime_par_foreign
            FOREIGN KEY (supprime_par) REFERENCES gnu.utilisateur(id) ON DELETE RESTRICT;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'gnu.utilisateur'::regclass
          AND conname = 'utilisateur_suppression_state_check'
    ) THEN
        ALTER TABLE gnu.utilisateur
            ADD CONSTRAINT utilisateur_suppression_state_check CHECK (
                (supprime_le IS NULL AND supprime_par IS NULL AND motif_suppression IS NULL)
                OR (
                    supprime_le IS NOT NULL
                    AND supprime_par IS NOT NULL
                    AND COALESCE(length(btrim(motif_suppression)), 0) >= 8
                    AND actif = false
                )
            );
    END IF;
END
$migration$;

GRANT SELECT (supprime_le, supprime_par, motif_suppression),
      UPDATE (supprime_le, supprime_par, motif_suppression)
ON gnu.utilisateur TO gnu_app;
SQL);
    }

    public function down(): void
    {
        if (DB::table('gnu.utilisateur')->whereNotNull('supprime_le')->exists()) {
            throw new RuntimeException('Des comptes ont été supprimés logiquement; leurs traces doivent être conservées.');
        }

        DB::unprepared(<<<'SQL'
REVOKE SELECT (supprime_le, supprime_par, motif_suppression),
       UPDATE (supprime_le, supprime_par, motif_suppression)
ON gnu.utilisateur FROM gnu_app;
ALTER TABLE gnu.utilisateur
    DROP CONSTRAINT IF EXISTS utilisateur_suppression_state_check,
    DROP CONSTRAINT IF EXISTS utilisateur_supprime_par_foreign,
    DROP COLUMN IF EXISTS motif_suppression,
    DROP COLUMN IF EXISTS supprime_par,
    DROP COLUMN IF EXISTS supprime_le;
SQL);
    }
};
