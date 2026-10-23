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

## Comptes de test GNU en local

Les comptes de test sont créés à la main depuis `http://127.0.0.1:8000/local-test-accounts`; aucune donnée d’acteur n’est injectée automatiquement. Copier `.env.example` vers `.env`, générer la clé Laravel et configurer une base PostgreSQL locale :

```bash
cp .env.example .env
php artisan key:generate
```

Dans `backend/.env`, garder `APP_ENV=local`, configurer `DB_*` pour l’API et vérifier que le portail est activé. Le modèle `.env.example` l’active pour les essais locaux; la configuration de production le garde désactivé. La connexion `GNU_LOCAL_SETUP_DB_*` doit être locale, viser la même base et utiliser un compte différent de `DB_USERNAME`, avec les droits de création nécessaires :

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

Pour désigner les administrateurs système, renseigner `GNU_PUBLICATION_ADMIN_LOGINS` avec un ou plusieurs logins Agent séparés par des virgules, puis recharger la configuration Laravel. Ces comptes gèrent la structure globale, approuvent les règles MGP/admission et attribuent le droit de publication aux autres agents. Ils ne peuvent pas s’attribuer eux-mêmes ce droit.

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
