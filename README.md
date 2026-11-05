# GNU — Gestion des notes universitaires

GNU est une application web/mobile de gestion des parcours académiques. Le dépôt contient un client Flutter et une API Laravel/Sanctum qui accède à PostgreSQL; Flutter ne se connecte jamais directement à la base.

**État fonctionnel au 3 novembre 2026 :** le porteur confirme que les parcours étudiant, enseignant et agent, les contrôles de rôles/périmètres, l’audit, les rattrapages, les bulletins, ainsi que le test sur téléphone sont acceptés. Les tests automatisés locaux sont verts. Le déploiement institutionnel et la recette sur une infrastructure HTTPS fournie par l’établissement restent des opérations d’environnement, pas des fonctions manquantes à coder.

## Parcours disponibles

- **Étudiant** : session, profil, inscriptions pédagogiques, consultation des résultats publiés, requêtes et justificatifs, notifications, candidatures de rattrapage et bulletins.
- **Enseignant** : affectations actives, configuration du plan d’évaluation et proposition de profil UE, carnet, saisie/import/transmission des notes, vérification des numérisations, requêtes assignées et rattrapages.
- **Agent** : travail limité au département attribué, structure et catalogue, classes et affectations, inscriptions, routage des requêtes, numérisation, audit, sessions et publication avec habilitation.

Les règles de notes sont centralisées dans `backend/config/academic.php` et `backend/app/Services/AcademicRules.php`. Le rattrapage est admissible pour une note de 0 à moins de 10/20; il est obligatoire jusqu’à 7,5 inclus et facultatif au-dessus. Une session unique est permise.

## Démarrer en local

Prérequis : PHP 8.5 avec `pdo_pgsql`, Composer, Flutter et une base PostgreSQL initialisée avec le schéma GNU attendu. Les secrets de connexion sont définis uniquement dans `backend/.env`; ne pas les copier dans Git.

Terminal 1 — API :

```bash
cd "/home/agent-47/Téléchargements/GNU---Gestion-des-notes-Universitaires/backend"
php artisan serve --host=127.0.0.1 --port=8000
```

Terminal 2 — client Web :

```bash
cd "/home/agent-47/Téléchargements/GNU---Gestion-des-notes-Universitaires/frontend"
flutter pub get
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8780 --dart-define=GNU_API_BASE_URL=http://127.0.0.1:8000/api/v1
```

Ouvrir <http://127.0.0.1:8780>.

### Tester depuis un téléphone sur le même Wi-Fi

Récupérer l’adresse IPv4 de l’ordinateur avec `ip -4 -o addr show scope global` et retenir celle de l’interface Wi-Fi (par exemple `192.168.1.25`). Dans les commandes suivantes, remplacer `192.168.1.25` par cette adresse.

Terminal 1 — API avec l’origine CORS locale :

```bash
cd "/home/agent-47/Téléchargements/GNU---Gestion-des-notes-Universitaires/backend"
CORS_ALLOWED_ORIGINS="http://127.0.0.1:8780,http://localhost:8780,http://192.168.1.25:8780" php artisan serve --host=0.0.0.0 --port=8000
```

Terminal 2 — interface joignant l’API par le réseau Wi-Fi :

```bash
cd "/home/agent-47/Téléchargements/GNU---Gestion-des-notes-Universitaires/frontend"
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8780 --dart-define=GNU_API_BASE_URL=http://192.168.1.25:8000/api/v1
```

Sur le téléphone, ouvrir `http://192.168.1.25:8780`. Le navigateur utilise un stockage local de test pour les sessions sur une adresse privée HTTP; ne pas utiliser de comptes réels dans ce mode. Le portail de création de comptes locaux est à `http://192.168.1.25:8000/local-test-accounts` si `GNU_ENABLE_LOCAL_TEST_ACCOUNT_PORTAL=true` est activé dans la configuration locale.

## Vérifications et build

```bash
cd backend
php artisan test
vendor/bin/pint --dirty --format agent

cd ../frontend
flutter test --no-pub
dart analyze lib/api_client.dart lib/session_storage.dart lib/session_storage_factory_stub.dart lib/session_storage_factory_web.dart
```

Une build Web de production demande l’URL HTTPS réelle de l’API, fournie par l’établissement :

```bash
cd frontend
GNU_API_BASE_URL=https://api-etablissement.example/api/v1 bash tool/build_production.sh
```

Ne pas utiliser une URL fictive pour un artefact destiné au déploiement. Pour une mise en service institutionnelle, configurer aussi CORS, secrets, comptes, base isolée, sauvegarde et restauration dans l’environnement visé.

## Documentation

- [Cahier des charges](docs/CAHIER_DES_CHARGES_GNU.tex)
- [Règles métier](docs/audit/05_audit_regles_metier.md)
- [Suivi frontend](docs/FRONTEND_PROGRESS.md)
- [État et livraison](docs/audit/09_validation_production.md)
- [Guide de tests manuels](docs/guide-tests-manuels.md)
- [Documentation backend](backend/README.md)
