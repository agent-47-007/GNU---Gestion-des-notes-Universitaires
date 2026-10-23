<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        DB::statement("CREATE TABLE gnu.session_rattrapage_ue (
            id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
            session_id bigint NOT NULL UNIQUE REFERENCES gnu.session_rattrapage(id) ON DELETE CASCADE,
            ue_id bigint NOT NULL REFERENCES gnu.ue(id) ON DELETE RESTRICT,
            statut_session varchar(20) NOT NULL CHECK (statut_session IN ('PREVUE', 'OUVERTE', 'CLOTUREE', 'ANNULEE')),
            created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
            updated_at timestamptz NOT NULL DEFAULT statement_timestamp()
        )");
        DB::statement('CREATE INDEX session_rattrapage_ue_ue_idx ON gnu.session_rattrapage_ue (ue_id)');
        DB::statement('GRANT SELECT, INSERT, UPDATE, DELETE ON gnu.session_rattrapage_ue TO gnu_app');
        DB::statement('GRANT USAGE, SELECT ON SEQUENCE gnu.session_rattrapage_ue_id_seq TO gnu_app');
        DB::statement('CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON gnu.session_rattrapage_ue FOR EACH ROW EXECUTE FUNCTION gnu.journaliser()');
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        DB::statement('DROP TRIGGER IF EXISTS zz_audit ON gnu.session_rattrapage_ue');
        DB::statement('REVOKE SELECT, INSERT, UPDATE, DELETE ON gnu.session_rattrapage_ue FROM gnu_app');
        DB::statement('REVOKE USAGE, SELECT ON SEQUENCE gnu.session_rattrapage_ue_id_seq FROM gnu_app');
        DB::statement('DROP TABLE gnu.session_rattrapage_ue');
    }
};
