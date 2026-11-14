<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::unprepared(<<<'SQL'
CREATE TABLE gnu.proces_verbal_note (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    transmission_id bigint NOT NULL UNIQUE REFERENCES gnu.transmission_note(id) ON DELETE RESTRICT,
    chemin_fichier text NOT NULL,
    empreinte_sha256 char(64) NOT NULL,
    genere_par bigint NOT NULL REFERENCES gnu.utilisateur(id) ON DELETE RESTRICT,
    publie_par bigint REFERENCES gnu.utilisateur(id) ON DELETE RESTRICT,
    publie_le timestamptz,
    created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
    updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
    CHECK ((publie_par IS NULL AND publie_le IS NULL) OR (publie_par IS NOT NULL AND publie_le IS NOT NULL))
);
CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON gnu.proces_verbal_note
    FOR EACH ROW EXECUTE FUNCTION gnu.journaliser();
GRANT SELECT, INSERT, UPDATE ON gnu.proces_verbal_note TO gnu_app;
GRANT USAGE, SELECT ON SEQUENCE gnu.proces_verbal_note_id_seq TO gnu_app;
SQL);
    }

    public function down(): void
    {
        if (DB::table('gnu.proces_verbal_note')->exists()) {
            throw new RuntimeException('Des procès-verbaux ont été créés; archivez-les avant de retirer cette fonctionnalité.');
        }
        DB::statement('DROP TRIGGER IF EXISTS zz_audit ON gnu.proces_verbal_note');
        DB::statement('REVOKE SELECT, INSERT, UPDATE ON gnu.proces_verbal_note FROM gnu_app');
        DB::statement('REVOKE USAGE, SELECT ON SEQUENCE gnu.proces_verbal_note_id_seq FROM gnu_app');
        DB::statement('DROP TABLE gnu.proces_verbal_note');
    }
};
