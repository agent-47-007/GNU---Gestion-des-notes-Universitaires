-- Recette du provisionnement, sur une base gnu_notes_test réservée aux tests.
-- Exécuter en administrateur après 001_creation.sql et 004_backend_laravel.sql.
-- Données fictives annulées; les compteurs de séquences peuvent avancer.
\set ON_ERROR_STOP on
BEGIN;
DO $$
BEGIN
  IF current_database() <> 'gnu_notes_test' THEN
    RAISE EXCEPTION 'La recette backend exige une base isolée nommée gnu_notes_test';
  END IF;
END
$$;
SET LOCAL ROLE gnu_app;
DO $$
DECLARE
  user_id bigint;
  token_id bigint;
  test_login text := '_GNU_BACKEND_TEST_' || txid_current();
BEGIN
  IF current_user <> 'gnu_app' THEN
    RAISE EXCEPTION 'La recette doit utiliser les droits effectifs de gnu_app';
  END IF;
  INSERT INTO gnu.utilisateur (code_utilisateur, login, mot_de_passe_hash, role, nom)
    VALUES (test_login, test_login, 'fixture-without-valid-password', 'AGENT', 'Recette backend')
    RETURNING id INTO user_id;
  IF NOT EXISTS (SELECT FROM gnu.journal_audit WHERE type_objet = 'utilisateur'
      AND identifiant_objet = user_id::text) THEN
    RAISE EXCEPTION 'Le trigger d''audit ne fonctionne pas avec gnu_app';
  END IF;
  INSERT INTO gnu_auth.personal_access_tokens
    (tokenable_type, tokenable_id, name, token, abilities, expires_at, created_at, updated_at)
    VALUES ('App\Models\Utilisateur', user_id, 'Recette backend', repeat('0', 64), '["*"]',
      statement_timestamp() + interval '1 hour', statement_timestamp(), statement_timestamp())
    RETURNING id INTO token_id;
  UPDATE gnu_auth.personal_access_tokens SET last_used_at = statement_timestamp() WHERE id = token_id;
  IF NOT EXISTS (SELECT FROM gnu_auth.personal_access_tokens WHERE id = token_id AND last_used_at IS NOT NULL) THEN
    RAISE EXCEPTION 'Écriture ou lecture du jeton Sanctum impossible';
  END IF;
  DELETE FROM gnu_auth.personal_access_tokens WHERE id = token_id;
  IF EXISTS (SELECT FROM gnu_auth.personal_access_tokens WHERE id = token_id) THEN
    RAISE EXCEPTION 'Révocation du jeton impossible';
  END IF;
  BEGIN
    INSERT INTO gnu_auth.personal_access_tokens (tokenable_type, tokenable_id, name, token)
      VALUES ('App\Models\Utilisateur', -1, 'Jeton orphelin interdit', repeat('1', 64));
    RAISE EXCEPTION 'La clé étrangère utilisateur doit refuser un jeton orphelin';
  EXCEPTION WHEN foreign_key_violation THEN NULL;
  END;
  BEGIN
    DELETE FROM gnu.utilisateur WHERE false;
    RAISE EXCEPTION 'DELETE métier doit être interdit';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    UPDATE gnu.journal_audit SET motif = 'interdit' WHERE false;
    RAISE EXCEPTION 'L''écriture directe du journal doit être interdite';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    CREATE TABLE gnu_auth._test_forbidden_create (id integer);
    RAISE EXCEPTION 'CREATE technique doit être interdit';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    CREATE TABLE public._test_forbidden_create (id integer);
    RAISE EXCEPTION 'CREATE public doit être interdit';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    CREATE TEMPORARY TABLE _test_forbidden_create (id integer);
    RAISE EXCEPTION 'CREATE TEMPORARY doit être interdit';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  RAISE NOTICE 'Recette backend réussie : jetons, audit, clé étrangère et restrictions de droits';
END
$$;
ROLLBACK;
