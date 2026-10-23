# Phase 2.5 — Tests et validation

| Contrôle | Résultat |
|---|---|
| Installation Composer depuis lock | Réussie, 115 paquets installés |
| `php artisan --version` | Réussi : Laravel 13.31.0 |
| `php artisan route:list --path=api` | Réussi : 21 routes |
| Connexion PostgreSQL live | Non validée depuis l'environnement d'audit |
| Tests Laravel | Non exécutés : `.env`/base de test non configurés |
| Tests Flutter | Déjà validés avant phase 2 : 13 tests |
| Build Flutter Web | Déjà validé avant phase 2 |
| Migrations/seeds | Non exécutés conformément à la consigne |

## Commandes de validation restantes

Après configuration locale et sans migration :

```bash
cd backend
php artisan config:clear
php artisan test
php artisan route:list --path=api
```

Puis tester les GET avec un compte de test non sensible et vérifier les codes HTTP, la pagination et les filtres.
