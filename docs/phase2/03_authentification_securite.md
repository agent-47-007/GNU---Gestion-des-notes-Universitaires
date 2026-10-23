# Phase 2.3 — Authentification et sécurité

## Existant vérifié

- Laravel Sanctum est déclaré dans `composer.json`.
- Middleware `auth:sanctum`, `account.active`, `role:*` et throttling sont présents dans `routes/api.php`.
- Routes login, register, logout, logout-all, profil et changement de mot de passe existent.
- Le fichier `backend/.gitignore` exclut `.env`, `vendor`, logs et caches.

## Limites

- Les tests HTTP n'ont pas été exécutés contre PostgreSQL réel.
- Le frontend Flutter ne consomme pas encore Sanctum.
- Les autorisations académiques enseignant/classe/EC ne sont pas implémentées.
- Les fichiers CSV étudiants restent des données personnelles à protéger avant toute nouvelle publication.

## Décision recommandée

Conserver Sanctum côté Laravel. Choisir explicitement cookies/CSRF ou tokens personnels pour Flutter Web avant l'intégration, puis ajouter des tests d'isolation par rôle.
