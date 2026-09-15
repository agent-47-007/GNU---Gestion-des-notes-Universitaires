-- psql -X -v ON_ERROR_STOP=1 -v app_role=gnu_app -f 003_droits.sql
-- Le rôle doit exister. Aucun login ni mot de passe n’est créé ici.
\if :{?app_role}
\else
\echo 'Variable app_role manquante'
\quit 2
\endif
SELECT :'app_role' <> current_user AS role_distinct \gset
\if :role_distinct
\else
\echo 'Le compte applicatif doit être distinct du propriétaire du schéma'
\quit 2
\endif
BEGIN;
GRANT USAGE ON SCHEMA gnu TO :"app_role";
GRANT USAGE ON TYPE gnu.texte_non_vide, gnu.nombre_fini, gnu.note_cent, gnu.credit_positif, gnu.poids_cent, gnu.mgp_quatre TO :"app_role";
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA gnu TO :"app_role";
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA gnu TO :"app_role";
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA gnu TO :"app_role";
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON gnu.historique_note, gnu.journal_audit, gnu.publication, gnu.bulletin FROM :"app_role";
-- La publication s’effectue uniquement via gnu.publier_classe().
-- Le rôle serveur applicatif est de confiance; il n’est jamais remis aux étudiants.
COMMIT;
