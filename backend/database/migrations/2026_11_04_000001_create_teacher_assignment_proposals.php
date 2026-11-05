<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::unprepared(<<<'SQL'
CREATE TABLE gnu.proposition_affectation_enseignant (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    affectation_id bigint NOT NULL REFERENCES gnu.affectation(id) ON DELETE RESTRICT,
    statut varchar(16) NOT NULL DEFAULT 'EN_ATTENTE'
        CHECK (statut IN ('EN_ATTENTE', 'APPROUVEE', 'REJETEE')),
    soumise_par bigint NOT NULL REFERENCES gnu.utilisateur(id) ON DELETE RESTRICT,
    decidee_par bigint REFERENCES gnu.utilisateur(id) ON DELETE RESTRICT,
    motif_enseignant text NOT NULL DEFAULT '',
    motif_decision text NOT NULL DEFAULT '',
    soumise_le timestamptz NOT NULL DEFAULT statement_timestamp(),
    decidee_le timestamptz,
    created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
    updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
    UNIQUE (id, affectation_id)
);
CREATE UNIQUE INDEX proposition_affectation_pending_unique
    ON gnu.proposition_affectation_enseignant (affectation_id)
    WHERE statut = 'EN_ATTENTE';
CREATE INDEX proposition_affectation_status_idx
    ON gnu.proposition_affectation_enseignant (statut, soumise_le DESC);
CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE
    ON gnu.proposition_affectation_enseignant
    FOR EACH ROW EXECUTE FUNCTION gnu.journaliser();
GRANT SELECT, INSERT, UPDATE ON gnu.proposition_affectation_enseignant TO gnu_app;
GRANT USAGE, SELECT ON SEQUENCE gnu.proposition_affectation_enseignant_id_seq TO gnu_app;
SQL);
    }

    public function down(): void
    {
        if (DB::table('gnu.proposition_affectation_enseignant')->exists()) {
            throw new RuntimeException('Des propositions d’affectation existent; archivez-les avant de retirer cette fonctionnalité.');
        }

        DB::statement('DROP TRIGGER IF EXISTS zz_audit ON gnu.proposition_affectation_enseignant');
        DB::statement('REVOKE SELECT, INSERT, UPDATE ON gnu.proposition_affectation_enseignant FROM gnu_app');
        DB::statement('REVOKE USAGE, SELECT ON SEQUENCE gnu.proposition_affectation_enseignant_id_seq FROM gnu_app');
        DB::statement('DROP TABLE gnu.proposition_affectation_enseignant');
    }
};
