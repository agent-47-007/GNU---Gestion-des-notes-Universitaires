# Rapport Phase 2 — Backend Laravel

## État global

Le backend Laravel a été restauré dans `backend/` depuis la sauvegarde, sans copier de secrets ni supprimer l'ancienne version. Les dépendances Composer sont installées depuis `composer.lock`. Laravel 13.31.0 charge correctement les routes.

## Réalisé

- backend canonique présent dans `backend/` ;
- PHP 8.5.4 et Composer 2.9.5 vérifiés ;
- Sanctum, middleware d'authentification et rôles conservés ;
- 8 endpoints GET de référentiels académiques ajoutés ;
- filtres et pagination ajoutés sans écriture de données ;
- aucune migration, suppression, mise à jour ou seeder exécuté ;
- documentation de phase 2 produite.

## Non validé

- connexion PostgreSQL réelle depuis Laravel ;
- réponses JSON des endpoints sur la base réelle ;
- tests Feature Laravel ;
- connexion Flutter à l'API ;
- policies académiques fines enseignant/classe/EC.

## Fichiers applicatifs modifiés

- `backend/app/Http/Controllers/AcademicReferenceController.php`
- `backend/routes/api.php`
- restauration du backend dans `backend/` depuis la sauvegarde.

## Risques encore présents

1. Le backend restauré doit recevoir un `.env` local non versionné.
2. Les données personnelles présentes dans les CSV ne doivent pas être exposées publiquement.
3. Les écarts de crédits `INF461`, `INF561`, `INF571` restent à arbitrer.
4. L'API ne couvre encore que les référentiels ; les notes et bulletins sont hors périmètre.

## Validation 2.6

La connexion PostgreSQL a été authentifiée, les privilèges `USAGE`/`SELECT` de `gnu_app` ont été vérifiés et Laravel lit réellement `gnu.ue` : 74 UE retournées. Les huit endpoints JSON et les tests HTTP restent à exécuter depuis le terminal utilisateur, les sockets locales étant bloquées dans l'environnement d'audit. Le détail vérifiable est dans `06_validation_laravel_postgresql.md`.

## Décision requise avant la phase 3

Configurer et tester la connexion PostgreSQL réelle, puis choisir la stratégie Sanctum pour Flutter Web. La phase 3 pourra ensuite intégrer le client Flutter aux endpoints de référentiels et d'authentification.
