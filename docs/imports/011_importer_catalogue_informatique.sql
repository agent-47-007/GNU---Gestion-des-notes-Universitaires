-- Actualise le catalogue Informatique unique à partir des fichiers CSV.
-- Chaque UE et EC existant est remplacé en place; aucune version n’est créée.
-- Exécuter depuis la racine du dépôt avec un rôle autorisé à écrire dans gnu.

\set ON_ERROR_STOP on
\i docs/imports/013_regle_ue_memoire_inf500.sql
\i docs/imports/002_import_ue_catalogue.sql
\i docs/imports/006_import_ec_catalogue.sql
\i docs/imports/012_activer_ue_memoire_inf500.sql
