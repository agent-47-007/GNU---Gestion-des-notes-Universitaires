<p align="center"><a href="https://laravel.com" target="_blank"><img src="https://raw.githubusercontent.com/laravel/art/master/logo-lockup/5%20SVG/2%20CMYK/1%20Full%20Color/laravel-logolockup-cmyk-red.svg" width="400" alt="Laravel Logo"></a></p>

<p align="center">
<a href="https://github.com/laravel/framework/actions"><img src="https://github.com/laravel/framework/workflows/tests/badge.svg" alt="Build Status"></a>
<a href="https://packagist.org/packages/laravel/framework"><img src="https://img.shields.io/packagist/dt/laravel/framework" alt="Total Downloads"></a>
<a href="https://packagist.org/packages/laravel/framework"><img src="https://img.shields.io/packagist/v/laravel/framework" alt="Latest Stable Version"></a>
<a href="https://packagist.org/packages/laravel/framework"><img src="https://img.shields.io/packagist/l/laravel/framework" alt="License"></a>
</p>

## About Laravel

Laravel is a web application framework with expressive, elegant syntax. We believe development must be an enjoyable and creative experience to be truly fulfilling. Laravel takes the pain out of development by easing common tasks used in many web projects, such as:

- [Simple, fast routing engine](https://laravel.com/docs/routing).
- [Powerful dependency injection container](https://laravel.com/docs/container).
- Multiple back-ends for [session](https://laravel.com/docs/session) and [cache](https://laravel.com/docs/cache) storage.
- Expressive, intuitive [database ORM](https://laravel.com/docs/eloquent).
- Database agnostic [schema migrations](https://laravel.com/docs/migrations).
- [Robust background job processing](https://laravel.com/docs/queues).
- [Real-time event broadcasting](https://laravel.com/docs/broadcasting).

Laravel is accessible, powerful, and provides tools required for large, robust applications.

## Learning Laravel

Laravel has the most extensive and thorough [documentation](https://laravel.com/docs) and video tutorial library of all modern web application frameworks, making it a breeze to get started with the framework.

In addition, [Laracasts](https://laracasts.com) contains thousands of video tutorials on a range of topics including Laravel, modern PHP, unit testing, and JavaScript. Boost your skills by digging into our comprehensive video library.

You can also watch bite-sized lessons with real-world projects on [Laravel Learn](https://laravel.com/learn), where you will be guided through building a Laravel application from scratch while learning PHP fundamentals.

## Agentic Development

Laravel's predictable structure and conventions make it ideal for AI coding agents like Claude Code, Cursor, and GitHub Copilot. Install [Laravel Boost](https://laravel.com/docs/ai) to supercharge your AI workflow:

```bash
composer require laravel/boost --dev

php artisan boost:install
```

Boost provides your agent 15+ tools and skills that help agents build Laravel applications while following best practices.

## Contributing

Thank you for considering contributing to the Laravel framework! The contribution guide can be found in the [Laravel documentation](https://laravel.com/docs/contributions).

## Code of Conduct

In order to ensure that the Laravel community is welcoming to all, please review and abide by the [Code of Conduct](https://laravel.com/docs/contributions#code-of-conduct).

## Security Vulnerabilities

If you discover a security vulnerability within Laravel, please send an e-mail to Taylor Otwell via [taylor@laravel.com](mailto:taylor@laravel.com). All security vulnerabilities will be promptly addressed.

## License

The Laravel framework is open-sourced software licensed under the [MIT license](https://opensource.org/licenses/MIT).

## Demandes officielles de compte

Les étudiants, enseignants et agents utilisent « Demander un compte » sur la page de connexion. Une demande ne crée aucun compte utilisable : l’administrateur système vérifie l’identité et le département, puis l’approuve ou la refuse depuis « Comptes & affectations ». L’approbation active le profil; pour un Agent, GNU crée aussi son rattachement départemental. La demande et la décision sont inscrites au journal d’audit. Le mot de passe est stocké sous forme de hash pendant l’examen puis supprimé de la demande après décision.

Le premier administrateur système s’amorce une seule fois depuis un terminal backend, avec la connexion PostgreSQL de configuration (`pgsql_setup`) pointant vers la base voulue :

```bash
php artisan gnu:bootstrap-system-admin
```

La commande demande confirmation du nom de la base, les informations de compte et le département, puis demande le mot de passe sans l’afficher. Elle crée un Agent actif, lui attribue son département et inscrit son rôle système avec trace d’audit. Ce droit est enregistré en base; aucune modification de `GNU_PUBLICATION_ADMIN_LOGINS` n’est requise. La commande refuse de s’exécuter si un administrateur système existe déjà. Aucun demandeur ne peut choisir ce rôle ni s’approuver lui-même.

Les migrations modifient parfois des tables institutionnelles et créent des clés étrangères vers des tables existantes. Utilisez le propriétaire PostgreSQL du schéma (généralement `postgres`) ou accordez temporairement au compte `gnu_setup` l’appartenance au rôle propriétaire. Les étapes et commandes `GRANT`/`REVOKE` sont détaillées dans le [guide de recette locale](../docs/guide-tests-manuels.md#activer-le-portail-local-de-création-des-comptes). N’utilisez pas le compte applicatif `gnu_app` pour appliquer les migrations.

Après avoir configuré le compte de propriétaire ou les droits temporaires, appliquez les migrations avec la connexion `pgsql_setup` :

```bash
GNU_LOCAL_SETUP_DB_USERNAME=postgres GNU_LOCAL_SETUP_DB_PASSWORD='…' php artisan migrate --database=pgsql_setup --no-interaction
```

La demande recueille une référence de pièce d’identité à contrôler. Le contrôle lui-même reste une action administrative; l’application n’envoie pas de copie de pièce et n’authentifie pas automatiquement l’identité.

## Comptes de test GNU en local

Les comptes de test sont créés à la main depuis `http://127.0.0.1:8000/local-test-accounts`; aucune donnée d’acteur n’est injectée automatiquement. Copier `.env.example` vers `.env`, générer la clé Laravel et configurer une base PostgreSQL locale :

```bash
cp .env.example .env
php artisan key:generate
```

Ce portail est réservé à une base de démonstration jetable; `GNU_ENABLE_LOCAL_TEST_ACCOUNT_PORTAL` reste désactivé par défaut. Ne l’activez pas sur la base officielle. Pour l’utiliser dans un environnement isolé, définissez explicitement `APP_ENV=local` et `GNU_ENABLE_LOCAL_TEST_ACCOUNT_PORTAL=true`; la connexion `GNU_LOCAL_SETUP_DB_*` doit viser uniquement la base de démonstration :

```dotenv
GNU_ENABLE_LOCAL_TEST_ACCOUNT_PORTAL=true
GNU_LOCAL_SETUP_DB_HOST=127.0.0.1
GNU_LOCAL_SETUP_DB_PORT=5435
GNU_LOCAL_SETUP_DB_DATABASE=gnu_notes
GNU_LOCAL_SETUP_DB_USERNAME=gnu_setup
GNU_LOCAL_SETUP_DB_PASSWORD=mot-de-passe-local
```

Après installation du schéma GNU et des migrations, ouvrir le portail local et créer un Agent avec son département, puis un Enseignant, puis un Étudiant avec sa classe. Le compte étudiant est prêt à choisir ses UE. Les logins et mots de passe sont choisis dans le formulaire; ils ne sont pas préremplis ni réinitialisés lors d’une exécution ultérieure. Utiliser des mots de passe locaux d’au moins 12 caractères. Le portail est désactivé par défaut et ne doit pas être activé sur un serveur public.

L’enseignant doit ensuite recevoir une affectation active depuis l’espace Agent avant de voir un cours. Le droit de publication officielle est attribué séparément.

Les administrateurs système actifs peuvent consulter et administrer les droits système depuis l’API Agent : `GET /api/v1/agent/administrateurs-systeme`, `PUT /api/v1/agent/administrateurs-systeme/{utilisateur}` avec un motif, puis `DELETE` sur la même ressource pour révoquer le droit. Un autre administrateur doit effectuer la révocation; le dernier administrateur actif est protégé. `GNU_PUBLICATION_ADMIN_LOGINS` reste disponible pour déclarer des administrateurs fixes par configuration; leur retrait se fait dans cette variable, pas par l’API. Les administrateurs gèrent la structure globale, approuvent les règles MGP/admission et attribuent le droit de publication aux autres agents. Aucun compte ne peut s’attribuer lui-même ce droit.

Pour le parcours complet de démarrage et les scénarios de recette manuelle, consulter [`../docs/guide-tests-manuels.md`](../docs/guide-tests-manuels.md).

Pour démarrer l’API après la création des comptes :

```bash
php artisan serve --host=127.0.0.1 --port=8000
```

Dans un autre terminal, lancer Flutter Web depuis `frontend/` avec l’URL de cette API :

```bash
cd ../frontend
flutter pub get
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8780 --dart-define=GNU_API_BASE_URL=http://127.0.0.1:8000/api/v1
```

Les trois comptes créés pourront ouvrir leurs espaces connectés. Le guide pas à pas avec les parcours de chaque acteur est dans [`../docs/guide-tests-manuels.md`](../docs/guide-tests-manuels.md).
