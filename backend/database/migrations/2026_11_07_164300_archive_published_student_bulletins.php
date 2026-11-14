<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::unprepared(<<<'SQL'
ALTER TABLE gnu.etudiant
    ADD COLUMN date_naissance date,
    ADD COLUMN lieu_naissance varchar(160);

CREATE TABLE gnu.document_bulletin (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    bulletin_id bigint NOT NULL UNIQUE REFERENCES gnu.bulletin(id) ON DELETE RESTRICT,
    reference_officielle varchar(200) NOT NULL UNIQUE,
    chemin_fichier text NOT NULL,
    empreinte_sha256 char(64) NOT NULL,
    genere_par bigint NOT NULL REFERENCES gnu.utilisateur(id) ON DELETE RESTRICT,
    date_emission timestamptz NOT NULL DEFAULT statement_timestamp(),
    created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
    updated_at timestamptz NOT NULL DEFAULT statement_timestamp()
);

CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON gnu.document_bulletin
    FOR EACH ROW EXECUTE FUNCTION gnu.journaliser();
GRANT SELECT, INSERT, UPDATE ON gnu.document_bulletin TO gnu_app;
GRANT USAGE, SELECT ON SEQUENCE gnu.document_bulletin_id_seq TO gnu_app;
GRANT SELECT (date_naissance, lieu_naissance), UPDATE (date_naissance, lieu_naissance) ON gnu.etudiant TO gnu_app;
SQL);
    }

    public function down(): void
    {
        if (DB::table('gnu.document_bulletin')->exists()) {
            throw new RuntimeException('Des bulletins PDF sont archivés. Exportez-les avant de retirer leur registre.');
        }

        DB::statement('DROP TRIGGER IF EXISTS zz_audit ON gnu.document_bulletin');
        DB::statement('REVOKE SELECT, INSERT, UPDATE ON gnu.document_bulletin FROM gnu_app');
        DB::statement('REVOKE USAGE, SELECT ON SEQUENCE gnu.document_bulletin_id_seq FROM gnu_app');
        DB::statement('REVOKE SELECT (date_naissance, lieu_naissance), UPDATE (date_naissance, lieu_naissance) ON gnu.etudiant FROM gnu_app');
        DB::statement('DROP TABLE gnu.document_bulletin');
        DB::statement('ALTER TABLE gnu.etudiant DROP COLUMN date_naissance, DROP COLUMN lieu_naissance');
    }
};
