<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::unprepared(<<<'SQL'
CREATE TABLE gnu.adhesion_salle_enseignant (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    enseignant_id bigint NOT NULL REFERENCES gnu.enseignant(id) ON DELETE RESTRICT,
    classe_id bigint NOT NULL REFERENCES gnu.classe(id) ON DELETE RESTRICT,
    created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
    updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
    UNIQUE (enseignant_id, classe_id)
);
CREATE INDEX adhesion_salle_classe_idx ON gnu.adhesion_salle_enseignant (classe_id, enseignant_id);
CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON gnu.adhesion_salle_enseignant
FOR EACH ROW EXECUTE FUNCTION gnu.journaliser();
GRANT SELECT, INSERT ON gnu.adhesion_salle_enseignant TO gnu_app;
GRANT USAGE, SELECT ON SEQUENCE gnu.adhesion_salle_enseignant_id_seq TO gnu_app;
SQL);
    }

    public function down(): void
    {
        if (DB::table('gnu.adhesion_salle_enseignant')->exists()) {
            throw new RuntimeException('Des adhésions de salle existent; archivez-les avant de retirer cette fonctionnalité.');
        }
        DB::statement('DROP TRIGGER IF EXISTS zz_audit ON gnu.adhesion_salle_enseignant');
        DB::statement('REVOKE SELECT, INSERT ON gnu.adhesion_salle_enseignant FROM gnu_app');
        DB::statement('REVOKE USAGE, SELECT ON SEQUENCE gnu.adhesion_salle_enseignant_id_seq FROM gnu_app');
        DB::statement('DROP TABLE gnu.adhesion_salle_enseignant');
    }
};
