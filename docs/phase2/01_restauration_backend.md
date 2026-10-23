# Phase 2.1 — Restauration du backend

## Actions effectuées

- Source retenue : `sauvegardes/ancienne-version-2026-10-12/source/GNU/GNU_Backend/`.
- Destination canonique : `backend/`.
- Fichiers restaurés : `app/`, `bootstrap/`, `config/`, `database/`, `routes/`, `tests/`, `artisan`, `composer.json`, `composer.lock` et documentation.
- Exclus : `.env`, `vendor/`, caches, logs et artefacts temporaires.
- Aucun fichier de sauvegarde historique n'a été supprimé.

## Vérifications

- PHP : 8.5.4.
- Composer : 2.9.5.
- Laravel : 13.31.0 après installation depuis `composer.lock`.
- `php artisan route:list --path=api` : 21 routes chargées après ajout des référentiels.
- Aucun `migrate`, `db:wipe`, seeder ou migration n'a été exécuté.

## État

Backend canonique restauré et exécutable en CLI. La configuration `.env` reste à créer localement avec les identifiants fournis par l'administrateur ; aucun secret n'est versionné.
