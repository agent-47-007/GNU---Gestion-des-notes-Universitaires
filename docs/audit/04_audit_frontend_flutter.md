# 04 — Audit frontend Flutter

## Architecture observée

Le point d'entrée est `frontend/lib/main.dart`. La navigation par rôle et les écrans sont répartis entre `pages.dart`, `features.dart` et `dialogs.dart`. L'état est porté par `DemoStore` dans `domain.dart` et transmis aux pages via `ChangeNotifier`.

## DemoStore

`DemoStore` contient des cours, notes, comptes, requêtes, affectations, sessions et programmes fictifs. Les recherches `DemoStore` montrent son utilisation dans `main.dart`, `pages.dart`, `features.dart` et `dialogs.dart`. Aucun package HTTP et aucun service API n'est déclaré dans `frontend/pubspec.yaml`.

## Écrans par rôle

| Espace | Interface | Données | État |
|---|---|---|---|
| Étudiant | tableau de bord, résultats, inscription, requêtes, profil | fictives | démonstration |
| Enseignant | classes, évaluations, notes, requêtes, rattrapages | fictives | démonstration |
| Agent | programmes, comptes, inscriptions, bulletins, audit, publication | fictives | démonstration |

Le thème clair/sombre est implémenté dans `main.dart`/`ui.dart`. La navigation responsive a été testée sur 390 et 1440 pixels. Les avertissements de clic hors écran dans le test d'agent restent non bloquants.

## Matrice d'intégration

| Écran Flutter | Endpoint réel correspondant | État |
|---|---|---|
| Connexion/profil | `/api/v1/auth/login`, `/auth/me` | backend sauvegardé, non consommé |
| Comptes agent | `/api/v1/comptes` | endpoint existant, non consommé |
| UE/EC/classes | absent | à créer |
| Inscriptions | absent | à créer |
| Notes/bulletins | absent | à créer |
| Requêtes/rattrapages/publication | absent | à créer |

## Conclusion

Le frontend est une maquette fonctionnelle et testée, pas encore un client de production connecté au backend.
