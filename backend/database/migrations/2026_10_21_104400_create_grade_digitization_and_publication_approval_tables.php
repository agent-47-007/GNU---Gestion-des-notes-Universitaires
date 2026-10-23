<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::unprepared(<<<'SQL'
CREATE TABLE gnu.note_numerisee (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    transmission_id bigint NOT NULL REFERENCES gnu.transmission_note(id) ON DELETE RESTRICT,
    evaluation_id bigint NOT NULL REFERENCES gnu.evaluation(id) ON DELETE RESTRICT,
    inscription_ue_id bigint NOT NULL REFERENCES gnu.inscription_ue(id) ON DELETE RESTRICT,
    valeur_note numeric(5,2),
    situation text NOT NULL CHECK (situation IN ('NUMERIQUE', 'ABSENTE')),
    version_note_source integer NOT NULL CHECK (version_note_source > 0),
    version_numerisation integer NOT NULL DEFAULT 1 CHECK (version_numerisation > 0),
    numerise_par bigint NOT NULL REFERENCES gnu.utilisateur(id) ON DELETE RESTRICT,
    motif text NOT NULL CHECK (length(trim(motif)) >= 8),
    created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
    updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
    UNIQUE (transmission_id, inscription_ue_id),
    CHECK ((situation = 'NUMERIQUE' AND valeur_note BETWEEN 0 AND 20) OR (situation = 'ABSENTE' AND valeur_note IS NULL))
);
CREATE INDEX note_numerisee_evaluation_idx ON gnu.note_numerisee (evaluation_id, inscription_ue_id);

CREATE OR REPLACE FUNCTION gnu.controle_note_numerisee() RETURNS trigger
LANGUAGE plpgsql SET search_path TO 'gnu', 'pg_catalog' AS $function$
DECLARE t transmission_note; e contexte_evaluation; ci contexte_inscription;
BEGIN
    SELECT * INTO t FROM transmission_note WHERE id = NEW.transmission_id;
    SELECT * INTO e FROM contexte_evaluation WHERE id = NEW.evaluation_id;
    SELECT * INTO ci FROM contexte_inscription WHERE inscription_ue_id = NEW.inscription_ue_id;
    PERFORM exiger(t.id IS NOT NULL AND t.evaluation_id = NEW.evaluation_id AND t.statut = 'TRANSMISE', 'Transmission absente ou déjà retournée');
    PERFORM exiger(ci.classe_id = e.classe_id AND ci.ue_id = e.ue_id AND ci.type_inscription <> 'CONSERVEE', 'Note hors inscription ou UE conservée');
    PERFORM exiger(EXISTS (
        SELECT 1 FROM utilisateur u
        JOIN classe c ON c.id = ci.classe_id
        JOIN niveau n ON n.id = c.niveau_id
        JOIN filiere f ON f.id = n.filiere_id
        WHERE u.id = acteur() AND u.role = 'AGENT' AND u.actif
          AND (EXISTS (SELECT 1 FROM agent_departement ad WHERE ad.agent_id = u.id AND ad.departement_id = f.departement_id)
            OR EXISTS (SELECT 1 FROM agent_administrateur_systeme aa WHERE aa.agent_id = u.id))
    ), 'Numérisation réservée à un agent actif du département de la classe');
    IF TG_OP = 'UPDATE' THEN
        NEW.version_numerisation := OLD.version_numerisation + 1;
        NEW.created_at := OLD.created_at;
    END IF;
    RETURN NEW;
END $function$;

CREATE TRIGGER a_controle_note_numerisee BEFORE INSERT OR UPDATE ON gnu.note_numerisee
FOR EACH ROW EXECUTE FUNCTION gnu.controle_note_numerisee();
CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON gnu.note_numerisee
FOR EACH ROW EXECUTE FUNCTION gnu.journaliser();

CREATE TABLE gnu.approbation_regles_publication (
    id smallint PRIMARY KEY CHECK (id = 1),
    version_moteur text NOT NULL,
    empreinte_regles char(64) NOT NULL,
    regles jsonb NOT NULL,
    approuve_par bigint NOT NULL REFERENCES gnu.utilisateur(id) ON DELETE RESTRICT,
    approuve_le timestamptz NOT NULL DEFAULT statement_timestamp(),
    created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
    updated_at timestamptz NOT NULL DEFAULT statement_timestamp()
);
CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON gnu.approbation_regles_publication
FOR EACH ROW EXECUTE FUNCTION gnu.journaliser();

CREATE TABLE gnu.agent_administrateur_systeme (
    agent_id bigint PRIMARY KEY REFERENCES gnu.utilisateur(id) ON DELETE RESTRICT,
    created_at timestamptz NOT NULL DEFAULT statement_timestamp()
);
CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON gnu.agent_administrateur_systeme
FOR EACH ROW EXECUTE FUNCTION gnu.journaliser();
CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON gnu.agent_departement
FOR EACH ROW EXECUTE FUNCTION gnu.journaliser();

REVOKE ALL ON FUNCTION gnu.controle_note_numerisee() FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON gnu.note_numerisee TO gnu_app;
GRANT USAGE, SELECT ON SEQUENCE gnu.note_numerisee_id_seq TO gnu_app;
GRANT SELECT, INSERT, UPDATE ON gnu.approbation_regles_publication TO gnu_app;
GRANT SELECT, INSERT, DELETE ON gnu.agent_administrateur_systeme TO gnu_app;
GRANT INSERT ON gnu.agent_departement TO gnu_app;
GRANT INSERT, DELETE ON gnu.agent_publication_autorisee TO gnu_app;
GRANT SELECT, INSERT, UPDATE ON gnu.universite, gnu.faculte, gnu.departement, gnu.filiere TO gnu_app;
GRANT USAGE, SELECT ON SEQUENCE gnu.universite_id_seq, gnu.faculte_id_seq, gnu.departement_id_seq, gnu.filiere_id_seq TO gnu_app;
CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON gnu.agent_publication_autorisee
FOR EACH ROW EXECUTE FUNCTION gnu.journaliser();
SQL);
    }

    public function down(): void
    {
        if (DB::table('gnu.note_numerisee')->exists() || DB::table('gnu.approbation_regles_publication')->exists()) {
            throw new RuntimeException('Des numérisations ou une approbation des règles existent; archivez-les avant de retirer ces workflows.');
        }
        DB::statement('DROP TRIGGER IF EXISTS zz_audit ON gnu.approbation_regles_publication');
        DB::statement('DROP TABLE gnu.approbation_regles_publication');
        DB::statement('DROP TRIGGER IF EXISTS zz_audit ON gnu.agent_administrateur_systeme');
        DB::statement('DROP TRIGGER IF EXISTS zz_audit ON gnu.agent_departement');
        DB::statement('REVOKE INSERT ON gnu.agent_departement FROM gnu_app');
        DB::statement('REVOKE SELECT, INSERT, DELETE ON gnu.agent_administrateur_systeme FROM gnu_app');
        DB::statement('DROP TABLE gnu.agent_administrateur_systeme');
        DB::statement('DROP TRIGGER IF EXISTS zz_audit ON gnu.agent_publication_autorisee');
        DB::statement('REVOKE INSERT, DELETE ON gnu.agent_publication_autorisee FROM gnu_app');
        DB::statement('REVOKE SELECT, INSERT, UPDATE ON gnu.universite, gnu.faculte, gnu.departement, gnu.filiere FROM gnu_app');
        DB::statement('REVOKE USAGE, SELECT ON SEQUENCE gnu.universite_id_seq, gnu.faculte_id_seq, gnu.departement_id_seq, gnu.filiere_id_seq FROM gnu_app');
        DB::statement('DROP TRIGGER IF EXISTS zz_audit ON gnu.note_numerisee');
        DB::statement('DROP TRIGGER IF EXISTS a_controle_note_numerisee ON gnu.note_numerisee');
        DB::statement('REVOKE SELECT, INSERT, UPDATE, DELETE ON gnu.note_numerisee FROM gnu_app');
        DB::statement('REVOKE USAGE, SELECT ON SEQUENCE gnu.note_numerisee_id_seq FROM gnu_app');
        DB::statement('DROP TABLE gnu.note_numerisee');
        DB::statement('DROP FUNCTION IF EXISTS gnu.controle_note_numerisee()');
    }
};
