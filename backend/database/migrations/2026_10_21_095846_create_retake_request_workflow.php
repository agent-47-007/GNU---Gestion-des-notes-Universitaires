<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::statement('ALTER TABLE gnu.requete DROP CONSTRAINT requete_type_requete_check');
        DB::statement("ALTER TABLE gnu.requete ADD CONSTRAINT requete_type_requete_check CHECK (type_requete IN ('ABSENCE', 'CONTESTATION', 'NOTE_MANQUANTE', 'REEVALUATION', 'AUTRE', 'CANDIDATURE_RATTRAPAGE'))");

        DB::statement('CREATE TABLE gnu.requete_rattrapage (
            requete_id bigint PRIMARY KEY REFERENCES gnu.requete(id) ON DELETE RESTRICT,
            session_id bigint NOT NULL REFERENCES gnu.session_rattrapage(id) ON DELETE RESTRICT,
            bulletin_source_id bigint NOT NULL REFERENCES gnu.bulletin(id) ON DELETE RESTRICT,
            created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
            updated_at timestamptz NOT NULL DEFAULT statement_timestamp()
        )');
        DB::statement('CREATE INDEX requete_rattrapage_session_idx ON gnu.requete_rattrapage (session_id)');
        DB::statement('GRANT SELECT, INSERT, UPDATE ON gnu.requete_rattrapage TO gnu_app');
        DB::statement('CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON gnu.requete_rattrapage FOR EACH ROW EXECUTE FUNCTION gnu.journaliser()');
    }

    public function down(): void
    {
        if (DB::table('gnu.requete')->where('type_requete', 'CANDIDATURE_RATTRAPAGE')->exists()) {
            throw new RuntimeException('Des candidatures de rattrapage existent; archivez-les avant de retirer leur workflow.');
        }

        DB::statement('DROP TRIGGER IF EXISTS zz_audit ON gnu.requete_rattrapage');
        DB::statement('REVOKE SELECT, INSERT, UPDATE ON gnu.requete_rattrapage FROM gnu_app');
        DB::statement('DROP TABLE gnu.requete_rattrapage');
        DB::statement('ALTER TABLE gnu.requete DROP CONSTRAINT requete_type_requete_check');
        DB::statement("ALTER TABLE gnu.requete ADD CONSTRAINT requete_type_requete_check CHECK (type_requete IN ('ABSENCE', 'CONTESTATION', 'NOTE_MANQUANTE', 'REEVALUATION', 'AUTRE'))");
    }
};
