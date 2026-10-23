# Phase 2.2 — Connexion PostgreSQL

## Configuration attendue

`.env.example` documente PostgreSQL, base `gnu_notes`, hôte local et port `5435`, avec schéma métier `gnu` utilisé par les modèles et les nouveaux contrôleurs. Les valeurs sensibles ne sont pas reproduites.

## Résultat

La connexion live n'a pas pu être validée depuis l'environnement d'exécution de l'agent : `psql` n'a pas fourni de connexion exploitable avec les identifiants disponibles. Laravel peut charger ses routes, mais un endpoint nécessitant PostgreSQL doit encore être testé sur la machine du projet.

## Commandes de validation à exécuter localement

```bash
cd backend
cp .env.example .env
php artisan key:generate
php artisan config:clear
php artisan tinker --execute="dump(DB::select('select current_database(), current_user'))"
php artisan route:list --path=api
```

Ne pas lancer de migration. Remplacer localement les paramètres DB par des valeurs valides sans les committer.
