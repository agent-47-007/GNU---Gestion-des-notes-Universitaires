# Phase 2.6 — Validation réelle Laravel/PostgreSQL

Date : 13 octobre 2026.

## Résultats

| Vérification | Résultat | Preuve |
|---|---|---|
| `.env` local | réussi | créé depuis `.env.example`, non versionné |
| PHP/pdo_pgsql | réussi | PHP 8.5.4 et extensions `PDO`, `pdo_pgsql` |
| Laravel | réussi | `Laravel Framework 13.31.0` |
| Authentification PostgreSQL | partiellement réussi | Laravel a retourné `gnu_notes` et `gnu_app` après changement du mot de passe |
| Droits schéma | réussi | `has_schema_privilege('gnu_app','gnu','USAGE') = t` |
| Droits SELECT | réussi | `ue_select`, `matiere_select`, `etudiant_select` = `t` |
| Lecture Laravel de `gnu.ue` | réussi | terminal utilisateur : `current_database=gnu_notes`, `current_user=gnu_app`, compteur `74` |
| Routes API | réussi | 21 routes chargées par `php artisan route:list --path=api` |
| 8 endpoints académiques sur données réelles | non validé | serveur HTTP local non joignable depuis l'environnement d'audit |
| Tests Feature Laravel | non exécutés | aucune base de test isolée configurée |
| Données académiques | préservées | aucune migration, écriture ou correction exécutée |

## Diagnostic

Le serveur PostgreSQL, les privilèges du rôle et la lecture Laravel sont maintenant confirmés depuis le terminal utilisateur. Le catalogue contient 74 UE. Le serveur HTTP et les appels JSON doivent encore être testés depuis le même terminal, car les sockets locales sont bloquées dans l'environnement de l'agent.

Commande de contrôle locale :

```bash
cd backend
php artisan config:clear
php artisan tinker --execute="dump(DB::select('select current_database(), current_user')); dump(DB::table('gnu.ue')->count())"
```

## Verdict

Phase 2.6 partiellement validée. Laravel est restauré, configuré et routeable ; l'accès aux données réelles et les réponses JSON des endpoints restent à confirmer dans l'environnement utilisateur.
