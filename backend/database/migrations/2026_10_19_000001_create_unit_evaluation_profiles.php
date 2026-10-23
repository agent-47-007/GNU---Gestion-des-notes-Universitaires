<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::statement("CREATE TABLE gnu.profil_evaluation_ue (
            ue_id bigint PRIMARY KEY REFERENCES gnu.ue(id) ON DELETE RESTRICT,
            code_profil varchar(20) NOT NULL CHECK (code_profil IN ('CC_SN', 'CC_TP_SN', 'CC_TPE_SN')),
            configure_par bigint NOT NULL REFERENCES gnu.utilisateur(id) ON DELETE RESTRICT,
            created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
            updated_at timestamptz NOT NULL DEFAULT statement_timestamp()
        )");
        DB::statement('GRANT SELECT, INSERT, UPDATE, DELETE ON gnu.profil_evaluation_ue TO gnu_app');
        DB::statement('CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON gnu.profil_evaluation_ue FOR EACH ROW EXECUTE FUNCTION gnu.journaliser()');
        DB::statement("CREATE TABLE gnu.proposition_profil_evaluation (
            id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
            ue_id bigint NOT NULL REFERENCES gnu.ue(id) ON DELETE RESTRICT,
            affectation_id bigint NOT NULL REFERENCES gnu.affectation(id) ON DELETE RESTRICT,
            enseignant_id bigint NOT NULL REFERENCES gnu.enseignant(id) ON DELETE RESTRICT,
            code_profil varchar(20) NOT NULL CHECK (code_profil IN ('CC_SN', 'CC_TP_SN', 'CC_TPE_SN')),
            statut varchar(16) NOT NULL DEFAULT 'EN_ATTENTE' CHECK (statut IN ('EN_ATTENTE', 'APPROUVEE', 'REJETEE')),
            created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
            updated_at timestamptz NOT NULL DEFAULT statement_timestamp()
        )");
        DB::statement("CREATE UNIQUE INDEX proposition_profil_en_attente_unique ON gnu.proposition_profil_evaluation (ue_id, enseignant_id, code_profil) WHERE statut = 'EN_ATTENTE'");
        DB::statement('CREATE INDEX proposition_profil_ue_statut_idx ON gnu.proposition_profil_evaluation (ue_id, statut, created_at DESC)');
        DB::statement('GRANT SELECT, INSERT, UPDATE, DELETE ON gnu.proposition_profil_evaluation TO gnu_app');
        DB::statement('GRANT USAGE, SELECT ON SEQUENCE gnu.proposition_profil_evaluation_id_seq TO gnu_app');
        DB::statement('CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON gnu.proposition_profil_evaluation FOR EACH ROW EXECUTE FUNCTION gnu.journaliser()');
    }

    public function down(): void
    {
        DB::statement('DROP TRIGGER IF EXISTS zz_audit ON gnu.profil_evaluation_ue');
        DB::statement('DROP TRIGGER IF EXISTS zz_audit ON gnu.proposition_profil_evaluation');
        DB::statement('REVOKE SELECT, INSERT, UPDATE, DELETE ON gnu.proposition_profil_evaluation FROM gnu_app');
        DB::statement('REVOKE USAGE, SELECT ON SEQUENCE gnu.proposition_profil_evaluation_id_seq FROM gnu_app');
        DB::statement('DROP TABLE gnu.proposition_profil_evaluation');
        DB::statement('REVOKE SELECT, INSERT, UPDATE, DELETE ON gnu.profil_evaluation_ue FROM gnu_app');
        DB::statement('DROP TABLE gnu.profil_evaluation_ue');
    }
};
