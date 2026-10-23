<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::statement("CREATE TABLE gnu.transmission_note (
            id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
            evaluation_id bigint NOT NULL REFERENCES gnu.evaluation(id) ON DELETE RESTRICT,
            affectation_id bigint NOT NULL REFERENCES gnu.affectation(id) ON DELETE RESTRICT,
            version integer NOT NULL CHECK (version > 0),
            statut varchar(20) NOT NULL CHECK (statut IN ('TRANSMISE', 'A_VERIFIER', 'A_CORRIGER', 'VERIFIEE')),
            enseignant_id bigint NOT NULL REFERENCES gnu.enseignant(id) ON DELETE RESTRICT,
            transmis_par bigint NOT NULL REFERENCES gnu.utilisateur(id) ON DELETE RESTRICT,
            transmis_le timestamptz NOT NULL DEFAULT statement_timestamp(),
            traite_par bigint REFERENCES gnu.utilisateur(id) ON DELETE RESTRICT,
            traite_le timestamptz,
            verifie_par bigint REFERENCES gnu.utilisateur(id) ON DELETE RESTRICT,
            verifie_le timestamptz,
            motif text NOT NULL CHECK (length(trim(motif)) >= 8),
            created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
            updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
            UNIQUE (evaluation_id, version),
            UNIQUE (id, evaluation_id),
            CHECK ((statut IN ('A_VERIFIER', 'A_CORRIGER', 'VERIFIEE') AND traite_par IS NOT NULL AND traite_le IS NOT NULL) OR statut = 'TRANSMISE'),
            CHECK ((statut = 'VERIFIEE' AND verifie_par IS NOT NULL AND verifie_le IS NOT NULL) OR statut <> 'VERIFIEE')
        )");
        DB::statement('CREATE INDEX transmission_note_affectation_statut_idx ON gnu.transmission_note (affectation_id, statut, transmis_le)');
        DB::statement("CREATE UNIQUE INDEX transmission_note_ouverte_unique ON gnu.transmission_note (evaluation_id) WHERE statut IN ('TRANSMISE', 'A_VERIFIER')");
        DB::statement('GRANT SELECT, INSERT, UPDATE ON gnu.transmission_note TO gnu_app');
        DB::statement('GRANT USAGE, SELECT ON SEQUENCE gnu.transmission_note_id_seq TO gnu_app');
        DB::statement('CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON gnu.transmission_note FOR EACH ROW EXECUTE FUNCTION gnu.journaliser()');
    }

    public function down(): void
    {
        DB::statement('DROP TRIGGER IF EXISTS zz_audit ON gnu.transmission_note');
        DB::statement('REVOKE SELECT, INSERT, UPDATE ON gnu.transmission_note FROM gnu_app');
        DB::statement('REVOKE USAGE, SELECT ON SEQUENCE gnu.transmission_note_id_seq FROM gnu_app');
        DB::statement('DROP TABLE gnu.transmission_note');
    }
};
