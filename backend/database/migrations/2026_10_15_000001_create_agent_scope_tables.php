<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::statement('CREATE TABLE gnu.agent_departement (
            agent_id bigint NOT NULL REFERENCES gnu.utilisateur(id) ON DELETE RESTRICT,
            departement_id bigint NOT NULL REFERENCES gnu.departement(id) ON DELETE RESTRICT,
            created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
            PRIMARY KEY (agent_id, departement_id)
        )');
        DB::statement('CREATE TABLE gnu.agent_publication_autorisee (
            agent_id bigint PRIMARY KEY REFERENCES gnu.utilisateur(id) ON DELETE RESTRICT,
            autorise_par bigint NOT NULL REFERENCES gnu.utilisateur(id) ON DELETE RESTRICT,
            created_at timestamptz NOT NULL DEFAULT statement_timestamp()
        )');
        DB::statement('CREATE TABLE gnu.agent_requete_transmission (
            id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
            requete_id bigint NOT NULL REFERENCES gnu.requete(id) ON DELETE RESTRICT,
            enseignant_id bigint NOT NULL REFERENCES gnu.enseignant(id) ON DELETE RESTRICT,
            agent_id bigint NOT NULL REFERENCES gnu.utilisateur(id) ON DELETE RESTRICT,
            version integer NOT NULL CHECK (version > 0),
            motif text NOT NULL CHECK (length(trim(motif)) >= 8),
            courante boolean NOT NULL DEFAULT true,
            created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
            UNIQUE (requete_id, version)
        )');
        DB::statement('CREATE UNIQUE INDEX agent_requete_transmission_courante_unique ON gnu.agent_requete_transmission (requete_id) WHERE courante');
        DB::statement('GRANT SELECT ON gnu.agent_departement, gnu.agent_publication_autorisee, gnu.agent_requete_transmission TO gnu_app');
        DB::statement('GRANT INSERT, UPDATE ON gnu.agent_requete_transmission TO gnu_app');
        DB::statement('GRANT USAGE, SELECT ON SEQUENCE gnu.agent_requete_transmission_id_seq TO gnu_app');
        DB::statement('CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON gnu.agent_requete_transmission FOR EACH ROW EXECUTE FUNCTION gnu.journaliser()');
        DB::statement('CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON gnu.inscription_semestre FOR EACH ROW EXECUTE FUNCTION gnu.journaliser()');
    }

    public function down(): void
    {
        DB::statement('DROP TRIGGER IF EXISTS zz_audit ON gnu.agent_requete_transmission');
        DB::statement('REVOKE SELECT, INSERT, UPDATE ON gnu.agent_requete_transmission FROM gnu_app');
        DB::statement('REVOKE USAGE, SELECT ON SEQUENCE gnu.agent_requete_transmission_id_seq FROM gnu_app');
        DB::statement('REVOKE SELECT ON gnu.agent_departement, gnu.agent_publication_autorisee FROM gnu_app');
        DB::statement('DROP TABLE gnu.agent_requete_transmission');
        DB::statement('DROP TRIGGER IF EXISTS zz_audit ON gnu.inscription_semestre');
        DB::statement('DROP TABLE gnu.agent_publication_autorisee');
        DB::statement('DROP TABLE gnu.agent_departement');
    }
};
