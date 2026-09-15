# GNU — Gestion des notes

Première itération démontrable du projet de stage, avec PostgreSQL local.

## Architecture principale

Flutter/Dart → API PHP locale → PostgreSQL local.

Flutter ne se connecte jamais directement à PostgreSQL. L’API applique les validations et appelle les fonctions métier du schéma `gnu`.

## Saisie et vérifications des notes — démonstration

La navigation enseignant ouvre un registre modifiable par UE puis EC. Les plans
d’exemple avec TP (20/30/50) et sans TP (30/70) déterminent les colonnes et les
compteurs. Une cellule vide représente une note manquante ; `ABS` représente une
absence. Les notes numériques se saisissent sur 20, avec point ou virgule.

Le calcul convertit les notes sur 100, applique les pondérations, arrondit chaque
EC à l’entier supérieur, puis calcule l’UE avec les crédits de ses EC et arrondit
à nouveau. Les grades suivent le barème SQL. Le seuil de 35/100 porte sur l’UE
pour l’admission annuelle ; une note faible de CC ne produit pas le statut EL.

Les contrôles et états sont séparés par EC : brouillon, validation, puis
transmission **simulée**. Une modification impose une nouvelle validation.
Les notes manquantes, invalides et les absences normales à régulariser bloquent
la finalisation. Les résultats affichés restent provisoires.

Le bouton de sauvegarde conserve les brouillons de démonstration dans le
navigateur ; sur les autres plateformes, ils sont conservés pendant la session
de l’application. Restaurer un brouillon impose une nouvelle validation. Les
imports/exports Excel et la transmission au Décanat sont simulés. Ce registre
ne lit ni n’écrit encore les notes du serveur.

Vérification : `cd frontend`, puis `flutter test` et `flutter build web`.

## Prérequis locaux

- PostgreSQL démarré sur le port `5435` ;
- base `gnu_notes` existante ;
- schéma `gnu` installé avec `GNU_Creation_PostgreSQL.sql` ;
- PHP avec l’extension `pdo_pgsql` ;
- Flutter, uniquement pour lancer l’interface.

Si la base n’est pas encore installée :

```bash
createdb -p 5435 -U postgres gnu_notes
psql -p 5435 -U postgres -d gnu_notes -v ON_ERROR_STOP=1 -f GNU_Creation_PostgreSQL.sql
psql -p 5435 -U postgres -d gnu_notes -v ON_ERROR_STOP=1 -f database/002_demo.sql
```

## Démarrer l’API sans Docker

```bash
cp .env.local.example .env.local
bash scripts/run-api-local.sh
```

Dans un autre terminal :

```bash
curl http://127.0.0.1:8080/api/health
bash scripts/check.sh
```

Routes principales : `/api/health`, `/api/dashboard`, `/api/classes`, `/api/students`, `/api/students/21T2355/bulletin?period=S1`.

## Démarrer Flutter

```bash
cd frontend
flutter pub get
flutter run -d chrome --dart-define=API_BASE=http://127.0.0.1:8080/api
```

## Docker — optionnel

Docker reste disponible avec `docker compose up --build` pour reproduire une installation isolée, mais il n’est plus nécessaire et ne doit pas être lancé en même temps qu’un PostgreSQL local utilisant le port `5435`.
