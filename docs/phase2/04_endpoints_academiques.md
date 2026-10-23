# Phase 2.4 — Endpoints académiques

## Endpoints créés

Le contrôleur `backend/app/Http/Controllers/AcademicReferenceController.php` expose en lecture seule, sous middleware Sanctum et compte actif :

- `GET /api/v1/referentiels/annees-academiques`
- `GET /api/v1/referentiels/filieres`
- `GET /api/v1/referentiels/specialites`
- `GET /api/v1/referentiels/niveaux`
- `GET /api/v1/referentiels/semestres`
- `GET /api/v1/referentiels/classes`
- `GET /api/v1/referentiels/ues`
- `GET /api/v1/referentiels/ecs`

Les requêtes utilisent le Query Builder Laravel sur le schéma `gnu`, avec filtres de niveau, filière, spécialité, année, semestre et UE selon l'endpoint, et pagination limitée à 100 éléments.

## Validation effectuée

`php artisan route:list --path=api` charge les 8 nouvelles routes et les routes d'authentification existantes. La réponse PostgreSQL réelle reste à valider après configuration locale de `.env`.

## Périmètre volontairement exclu

Aucune écriture, note, bulletin, publication, requête ou rattrapage n'a été ajouté durant cette phase.
