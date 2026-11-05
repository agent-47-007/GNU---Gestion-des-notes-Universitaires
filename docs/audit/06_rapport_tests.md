# 06 — Rapport de tests

> **Archive d’audit historique.** Ce document reflète l’état constaté lors de sa rédaction et a été dépassé par les travaux ultérieurs. Pour l’état fonctionnel accepté au 3 novembre 2026 et les seuls prérequis de livraison encore ouverts, consulter [l’état actuel](09_validation_production.md) et [les règles métier](05_audit_regles_metier.md).

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
