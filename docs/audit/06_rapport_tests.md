# 06 — Rapport de tests

## Tests Flutter

| Commande | Résultat | Preuve |
|---|---|---|
| `flutter test --no-pub` | réussi, 13 tests | sortie terminal : `All tests passed!` |
| `flutter build web --no-pub` | réussi | sortie terminal : `Built build/web` |
| `flutter run -d chrome` | bloqué environnement | Chrome/Snap échoue au lancement ; utiliser `-d web-server` |

Les tests ont émis des avertissements de clic hors écran sur « Validation & publication », sans échec final.

## Tests Laravel/PostgreSQL

Non exécutés pendant cet audit : le backend actif n'est pas à la racine et une connexion live PostgreSQL en lecture seule n'a pas été obtenue depuis l'environnement d'audit. Les commandes d'import antérieures ont été exécutées par le responsable du projet, mais ne constituent pas un test d'intégration Laravel.

## Verdict

La qualité Flutter de démonstration est validée. La chaîne API--PostgreSQL reste non testée.
