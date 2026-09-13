-- Provisionnement administrateur : psql -X -v ON_ERROR_STOP=1 -f 004_backend_laravel.sql
-- À exécuter après 001_creation.sql dans gnu_notes ou gnu_notes_test.
-- Aucun mot de passe n'est fourni ici; utiliser ensuite \password gnu_app.
\set ON_ERROR_STOP on
SELECT current_database() AS backend_database \gset
BEGIN;

DO $$
BEGIN
  IF current_database() NOT IN ('gnu_notes', 'gnu_notes_test') THEN
    RAISE EXCEPTION 'Ce provisionnement cible exclusivement gnu_notes ou gnu_notes_test';
  END IF;
  IF to_regclass('gnu.utilisateur') IS NULL THEN
    RAISE EXCEPTION 'Installer le schéma métier gnu avant le backend';
  END IF;
  IF current_user = 'gnu_app' THEN
    RAISE EXCEPTION 'Utiliser le compte administrateur propriétaire des objets';
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'gnu_app') THEN
    CREATE ROLE gnu_app LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE
      NOINHERIT NOREPLICATION NOBYPASSRLS;
  END IF;
  IF EXISTS (
    SELECT FROM pg_roles WHERE rolname = 'gnu_app'
      AND (rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls OR NOT rolcanlogin)
  ) OR EXISTS (
    SELECT FROM pg_auth_members m JOIN pg_roles r ON r.oid = m.member
    WHERE r.rolname = 'gnu_app'
  ) THEN
    RAISE EXCEPTION 'gnu_app doit être LOGIN, sans administration ni appartenance à un autre rôle';
  END IF;
  IF EXISTS (
    SELECT FROM pg_database WHERE datname = current_database()
      AND datdba = (SELECT oid FROM pg_roles WHERE rolname = 'gnu_app')
  ) OR EXISTS (
    SELECT FROM pg_namespace WHERE nspowner = (SELECT oid FROM pg_roles WHERE rolname = 'gnu_app')
  ) OR EXISTS (
    SELECT FROM pg_class WHERE relowner = (SELECT oid FROM pg_roles WHERE rolname = 'gnu_app')
  ) OR EXISTS (
    SELECT FROM pg_proc WHERE proowner = (SELECT oid FROM pg_roles WHERE rolname = 'gnu_app')
  ) THEN
    RAISE EXCEPTION 'gnu_app ne doit posséder ni base, ni schéma, ni objet';
  END IF;
END
$$;

ALTER ROLE gnu_app IN DATABASE :"backend_database" SET search_path = gnu, gnu_auth, pg_catalog;
-- TEMPORARY permettrait de masquer des relations utilisées par les fonctions
-- métier SECURITY DEFINER dont le search_path n'explicite pas pg_temp.
REVOKE CREATE, TEMPORARY ON DATABASE :"backend_database" FROM PUBLIC, gnu_app;
GRANT CONNECT ON DATABASE :"backend_database" TO gnu_app;
-- PostgreSQL 14 accorde CREATE sur public à PUBLIC par défaut. Un REVOKE
-- individuel ne peut pas annuler ce droit hérité. Cette base est dédiée à GNU.
REVOKE CREATE ON SCHEMA public FROM PUBLIC, gnu_app;

-- Droits métier identiques à 003_droits.sql, dans cette transaction unique.
REVOKE ALL ON SCHEMA gnu FROM gnu_app;
GRANT USAGE ON SCHEMA gnu TO gnu_app;
GRANT USAGE ON TYPE gnu.texte_non_vide, gnu.nombre_fini, gnu.note_cent,
  gnu.credit_positif, gnu.poids_cent, gnu.mgp_quatre TO gnu_app;
REVOKE ALL ON ALL TABLES IN SCHEMA gnu FROM gnu_app;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA gnu TO gnu_app;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA gnu FROM gnu_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA gnu TO gnu_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA gnu TO gnu_app;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE
  ON gnu.historique_note, gnu.journal_audit, gnu.publication, gnu.bulletin FROM gnu_app;

CREATE SCHEMA IF NOT EXISTS gnu_auth;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT FROM pg_namespace n JOIN pg_roles r ON r.oid = n.nspowner
    WHERE n.nspname = 'gnu_auth' AND r.rolname = current_user
  ) THEN
    RAISE EXCEPTION 'gnu_auth doit appartenir au compte exécutant le provisionnement';
  END IF;
END
$$;
REVOKE ALL ON SCHEMA gnu_auth FROM PUBLIC, gnu_app;
GRANT USAGE ON SCHEMA gnu_auth TO gnu_app;

-- Sanctum utilise uniquement le modèle utilisateur GNU comme tokenable.
CREATE TABLE IF NOT EXISTS gnu_auth.personal_access_tokens (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tokenable_type varchar(255) NOT NULL,
  tokenable_id bigint NOT NULL REFERENCES gnu.utilisateur(id) ON DELETE CASCADE,
  name varchar(255) NOT NULL,
  token varchar(64) NOT NULL UNIQUE,
  abilities text,
  last_used_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz
);
CREATE INDEX IF NOT EXISTS personal_access_tokens_tokenable_index
  ON gnu_auth.personal_access_tokens (tokenable_type, tokenable_id);
CREATE INDEX IF NOT EXISTS personal_access_tokens_expires_at_index
  ON gnu_auth.personal_access_tokens (expires_at);
REVOKE ALL ON ALL TABLES IN SCHEMA gnu_auth FROM PUBLIC, gnu_app;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA gnu_auth FROM PUBLIC, gnu_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON gnu_auth.personal_access_tokens TO gnu_app;
GRANT USAGE, SELECT ON SEQUENCE gnu_auth.personal_access_tokens_id_seq TO gnu_app;

-- Les droits hérités de PUBLIC doivent également respecter la séparation.
DO $$
BEGIN
  IF has_database_privilege('gnu_app', current_database(), 'CREATE')
    OR has_database_privilege('gnu_app', current_database(), 'TEMPORARY') OR EXISTS (
    SELECT FROM pg_namespace WHERE nspname !~ '^pg_' AND nspname <> 'information_schema'
      AND has_schema_privilege('gnu_app', oid, 'CREATE')
  ) THEN
    RAISE EXCEPTION 'gnu_app possède encore CREATE ou TEMPORARY; corriger les droits administrateur';
  END IF;
  IF EXISTS (
    SELECT FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname IN ('gnu', 'gnu_auth') AND c.relkind IN ('r', 'p', 'v', 'm', 'f')
      AND (has_table_privilege('gnu_app', c.oid, 'TRUNCATE')
        OR (c.oid <> 'gnu_auth.personal_access_tokens'::regclass
          AND has_table_privilege('gnu_app', c.oid, 'DELETE')))
  ) THEN
    RAISE EXCEPTION 'gnu_app possède un droit de suppression non autorisé';
  END IF;
  IF EXISTS (
    SELECT FROM (VALUES ('gnu.historique_note'), ('gnu.journal_audit'),
      ('gnu.publication'), ('gnu.bulletin')) AS protected(name)
    WHERE has_table_privilege('gnu_app', name, 'INSERT')
       OR has_table_privilege('gnu_app', name, 'UPDATE')
  ) THEN
    RAISE EXCEPTION 'gnu_app possède un droit direct d''écriture sur les historiques ou publications';
  END IF;
END
$$;
COMMIT;
\echo 'Rôle gnu_app et table gnu_auth.personal_access_tokens prêts. Définir le mot de passe avec preparer_backend.sh --password.'
