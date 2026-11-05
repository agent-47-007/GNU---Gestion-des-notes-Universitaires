<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::unprepared(<<<'SQL'
CREATE TABLE gnu.logo_structure (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    universite_id bigint REFERENCES gnu.universite(id) ON DELETE RESTRICT,
    faculte_id bigint REFERENCES gnu.faculte(id) ON DELETE RESTRICT,
    departement_id bigint REFERENCES gnu.departement(id) ON DELETE RESTRICT,
    chemin_fichier text NOT NULL,
    type_mime varchar(32) NOT NULL CHECK (type_mime IN ('image/png', 'image/jpeg', 'image/webp')),
    updated_by bigint NOT NULL REFERENCES gnu.utilisateur(id) ON DELETE RESTRICT,
    created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
    updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
    CHECK (num_nonnulls(universite_id, faculte_id, departement_id) = 1)
);
CREATE UNIQUE INDEX logo_structure_universite_unique ON gnu.logo_structure(universite_id) WHERE universite_id IS NOT NULL;
CREATE UNIQUE INDEX logo_structure_faculte_unique ON gnu.logo_structure(faculte_id) WHERE faculte_id IS NOT NULL;
CREATE UNIQUE INDEX logo_structure_departement_unique ON gnu.logo_structure(departement_id) WHERE departement_id IS NOT NULL;
GRANT SELECT, INSERT, UPDATE ON gnu.logo_structure TO gnu_app;
GRANT USAGE, SELECT ON SEQUENCE gnu.logo_structure_id_seq TO gnu_app;
CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON gnu.logo_structure FOR EACH ROW EXECUTE FUNCTION gnu.journaliser();
SQL);
    }

    public function down(): void
    {
        DB::statement('DROP TRIGGER IF EXISTS zz_audit ON gnu.logo_structure');
        DB::statement('REVOKE SELECT, INSERT, UPDATE ON gnu.logo_structure FROM gnu_app');
        DB::statement('REVOKE USAGE, SELECT ON SEQUENCE gnu.logo_structure_id_seq FROM gnu_app');
        DB::statement('DROP TABLE gnu.logo_structure');
    }
};
