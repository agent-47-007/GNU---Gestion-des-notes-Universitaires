<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::unprepared(<<<'SQL'
CREATE TABLE gnu.note_hors_compte (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    classe_id bigint NOT NULL REFERENCES gnu.classe(id) ON DELETE RESTRICT,
    ue_id bigint NOT NULL REFERENCES gnu.ue(id) ON DELETE RESTRICT,
    evaluation_id bigint NOT NULL REFERENCES gnu.evaluation(id) ON DELETE RESTRICT,
    affectation_id bigint NOT NULL REFERENCES gnu.affectation(id) ON DELETE RESTRICT,
    matricule varchar(32) NOT NULL,
    nom varchar(180) NOT NULL,
    valeur_note numeric(5,2),
    situation varchar(16) NOT NULL DEFAULT 'MANQUANTE' CHECK (situation IN ('NUMERIQUE', 'ABSENTE', 'MANQUANTE')),
    statut_note varchar(16) NOT NULL DEFAULT 'BROUILLON' CHECK (statut_note IN ('BROUILLON', 'VALIDEE')),
    version_note integer NOT NULL DEFAULT 1 CHECK (version_note > 0),
    observation text NOT NULL DEFAULT 'Étudiant sans compte sur la plateforme.',
    cree_par bigint NOT NULL REFERENCES gnu.utilisateur(id) ON DELETE RESTRICT,
    created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
    updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
    UNIQUE (evaluation_id, matricule),
    CHECK ((situation = 'NUMERIQUE' AND valeur_note BETWEEN 0 AND 20) OR (situation IN ('ABSENTE', 'MANQUANTE') AND valeur_note IS NULL))
);
CREATE INDEX note_hors_compte_classe_evaluation_idx ON gnu.note_hors_compte (classe_id, evaluation_id, matricule);
CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON gnu.note_hors_compte
    FOR EACH ROW EXECUTE FUNCTION gnu.journaliser();

CREATE TABLE gnu.transmission_note_hors_compte (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    transmission_id bigint NOT NULL REFERENCES gnu.transmission_note(id) ON DELETE RESTRICT,
    note_hors_compte_id bigint NOT NULL REFERENCES gnu.note_hors_compte(id) ON DELETE RESTRICT,
    matricule varchar(32) NOT NULL,
    nom varchar(180) NOT NULL,
    valeur_note numeric(5,2),
    situation varchar(16) NOT NULL CHECK (situation IN ('NUMERIQUE', 'ABSENTE')),
    version_note_source integer NOT NULL CHECK (version_note_source > 0),
    created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
    updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
    UNIQUE (transmission_id, note_hors_compte_id),
    CHECK ((situation = 'NUMERIQUE' AND valeur_note BETWEEN 0 AND 20) OR (situation = 'ABSENTE' AND valeur_note IS NULL))
);
CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON gnu.transmission_note_hors_compte
    FOR EACH ROW EXECUTE FUNCTION gnu.journaliser();

CREATE TABLE gnu.note_numerisee_hors_compte (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    transmission_id bigint NOT NULL REFERENCES gnu.transmission_note(id) ON DELETE RESTRICT,
    note_hors_compte_id bigint NOT NULL REFERENCES gnu.note_hors_compte(id) ON DELETE RESTRICT,
    valeur_note numeric(5,2),
    situation varchar(16) NOT NULL CHECK (situation IN ('NUMERIQUE', 'ABSENTE')),
    version_note_source integer NOT NULL CHECK (version_note_source > 0),
    version_numerisation integer NOT NULL DEFAULT 1 CHECK (version_numerisation > 0),
    numerise_par bigint NOT NULL REFERENCES gnu.utilisateur(id) ON DELETE RESTRICT,
    motif text NOT NULL CHECK (length(trim(motif)) >= 8),
    created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
    updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
    UNIQUE (transmission_id, note_hors_compte_id),
    CHECK ((situation = 'NUMERIQUE' AND valeur_note BETWEEN 0 AND 20) OR (situation = 'ABSENTE' AND valeur_note IS NULL))
);
CREATE FUNCTION gnu.verifier_note_hors_compte_scope() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM gnu.evaluation ev
        JOIN gnu.affectation a ON a.id = ev.affectation_id
        JOIN gnu.matiere m ON m.id = a.matiere_id
        WHERE ev.id = NEW.evaluation_id
          AND a.id = NEW.affectation_id
          AND a.classe_id = NEW.classe_id
          AND m.ue_id = NEW.ue_id
          AND ev.mode_evaluation = 'NORMALE'
    ) THEN
        RAISE EXCEPTION 'La note hors compte doit correspondre à une évaluation normale de cette affectation, classe et UE.';
    END IF;
    NEW.updated_at := statement_timestamp();
    RETURN NEW;
END;
$$;
CREATE TRIGGER verifier_note_hors_compte_scope
    BEFORE INSERT OR UPDATE ON gnu.note_hors_compte
    FOR EACH ROW EXECUTE FUNCTION gnu.verifier_note_hors_compte_scope();
CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON gnu.note_numerisee_hors_compte
    FOR EACH ROW EXECUTE FUNCTION gnu.journaliser();

GRANT SELECT, INSERT, UPDATE, DELETE ON gnu.note_hors_compte, gnu.transmission_note_hors_compte, gnu.note_numerisee_hors_compte TO gnu_app;
GRANT USAGE, SELECT ON SEQUENCE gnu.note_hors_compte_id_seq, gnu.transmission_note_hors_compte_id_seq, gnu.note_numerisee_hors_compte_id_seq TO gnu_app;
SQL);
    }

    public function down(): void
    {
        DB::unprepared(<<<'SQL'
DROP TABLE IF EXISTS gnu.note_numerisee_hors_compte;
DROP TABLE IF EXISTS gnu.transmission_note_hors_compte;
DROP TABLE IF EXISTS gnu.note_hors_compte;
DROP FUNCTION IF EXISTS gnu.verifier_note_hors_compte_scope();
SQL);
    }
};
