<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::unprepared(<<<'SQL'
CREATE TABLE gnu.demande_compte (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    role varchar(16) NOT NULL CHECK (role IN ('ETUDIANT', 'ENSEIGNANT', 'AGENT')),
    login varchar(64) NOT NULL,
    code_utilisateur varchar(64) NOT NULL,
    nom varchar(120) NOT NULL,
    prenom varchar(120) NOT NULL,
    courriel varchar(254),
    identifiant_profil varchar(64) NOT NULL,
    departement_id bigint NOT NULL REFERENCES gnu.departement(id) ON DELETE RESTRICT,
    filiere_id bigint REFERENCES gnu.filiere(id) ON DELETE RESTRICT,
    specialite_id bigint REFERENCES gnu.specialite(id) ON DELETE RESTRICT,
    reference_identite varchar(160) NOT NULL,
    mot_de_passe_hash text,
    statut varchar(16) NOT NULL DEFAULT 'EN_ATTENTE' CHECK (statut IN ('EN_ATTENTE', 'APPROUVEE', 'REJETEE')),
    soumise_le timestamptz NOT NULL DEFAULT statement_timestamp(),
    decidee_par bigint REFERENCES gnu.utilisateur(id) ON DELETE RESTRICT,
    decidee_le timestamptz,
    motif_decision text NOT NULL DEFAULT '',
    utilisateur_cree_id bigint REFERENCES gnu.utilisateur(id) ON DELETE RESTRICT,
    created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
    updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
    CHECK ((statut = 'EN_ATTENTE' AND decidee_par IS NULL AND decidee_le IS NULL AND utilisateur_cree_id IS NULL AND mot_de_passe_hash IS NOT NULL)
        OR (statut = 'APPROUVEE' AND decidee_par IS NOT NULL AND decidee_le IS NOT NULL AND utilisateur_cree_id IS NOT NULL AND mot_de_passe_hash IS NULL)
        OR (statut = 'REJETEE' AND decidee_par IS NOT NULL AND decidee_le IS NOT NULL AND utilisateur_cree_id IS NULL AND mot_de_passe_hash IS NULL)),
    CHECK (length(trim(reference_identite)) >= 4)
);
CREATE UNIQUE INDEX demande_compte_pending_login_unique ON gnu.demande_compte (lower(login)) WHERE statut = 'EN_ATTENTE';
CREATE UNIQUE INDEX demande_compte_pending_profile_unique ON gnu.demande_compte (role, upper(identifiant_profil)) WHERE statut = 'EN_ATTENTE';
CREATE INDEX demande_compte_review_idx ON gnu.demande_compte (role, departement_id, statut, soumise_le);
CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON gnu.demande_compte
    FOR EACH ROW EXECUTE FUNCTION gnu.journaliser();
GRANT SELECT, INSERT, UPDATE ON gnu.demande_compte TO gnu_app;
GRANT USAGE, SELECT ON SEQUENCE gnu.demande_compte_id_seq TO gnu_app;
SQL);
    }

    public function down(): void
    {
        DB::statement('DROP TABLE IF EXISTS gnu.demande_compte');
    }
};
