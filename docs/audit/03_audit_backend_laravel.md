# 03 — Audit backend Laravel

## Localisation

Le backend auditable est dans `sauvegardes/ancienne-version-2026-10-12/source/GNU/GNU_Backend/`, pas dans `backend/` courant, qui ne contient que `.gitkeep`.

## Stack observée

`composer.json` déclare PHP `^8.5`, Laravel `^13.17`, Sanctum `^4.3` et `ext-pdo_pgsql`. Les modèles, contrôleurs, Form Requests et middleware sont présents dans `app/`.

## Routes inventoriées

| Méthode | Route | Contrôleur | Protection | État observé |
|---|---|---|---|---|
| POST | `/api/v1/auth/login` | `AuthController` | throttle login | implémentée |
| POST | `/api/v1/auth/register` | `RegistrationController` | throttle login | implémentée |
| GET | `/api/v1/auth/me` | `ProfileController` | Sanctum + compte actif | implémentée |
| POST | `/api/v1/auth/logout` | `AuthController` | Sanctum | implémentée |
| POST | `/api/v1/auth/logout-all` | `AuthController` | Sanctum | implémentée |
| PUT | `/api/v1/auth/password` | `AuthController` | Sanctum + throttle | implémentée |
| GET | `/api/v1/profil/{etudiant,enseignant,agent}` | `ProfileController` | Sanctum + rôle | partielle |
| GET/POST/SHOW/PUT | `/api/v1/comptes` | `AccountController` | rôle AGENT | implémentée |

## Diagnostic

L'authentification et la gestion de comptes sont couvertes par des contrôleurs et des tests Feature dans la sauvegarde. Les endpoints académiques (UE, EC, classes, inscriptions, notes, bulletins, requêtes, rattrapages, publications) ne sont pas exposés dans `routes/api.php` audité. Le frontend actuel ne contient aucun client HTTP et ne consomme donc pas ces routes.

## Risques

- Backend absent de la racine active : intégration impossible sans décision d'architecture.
- Couverture API très incomplète par rapport au cahier des charges.
- Autorisations métier fines enseignant/classe/EC non démontrées par les routes disponibles.

## Conclusion

Le socle d'authentification Laravel/Sanctum est le seul périmètre backend démontré. Il faut d'abord réintégrer/activer le backend et inventorier ses migrations sans modifier la base réelle.
