# 07 — Sécurité et risques

> **Archive d’audit historique.** Ce document reflète l’état constaté lors de sa rédaction et a été dépassé par les travaux ultérieurs. Pour l’état fonctionnel accepté au 3 novembre 2026 et les seuls prérequis de livraison encore ouverts, consulter [l’état actuel](09_validation_production.md) et [les règles métier](05_audit_regles_metier.md).

| Gravité | Risque | Preuve | Impact | Recommandation |
|---|---|---|---|---|
| Critique | Frontend non connecté à l'API réelle | absence de client HTTP, `DemoStore` | données fictives et aucun contrôle serveur depuis Flutter | intégrer Sanctum et services API |
| Élevée | Backend actif absent de la racine | `backend/.gitkeep`, backend dans sauvegarde | déploiement et maintenance ambigus | décider puis documenter l'emplacement canonique |
| Élevée | Données personnelles présentes dans les CSV/commits | `inf361_sr_students.csv` | exposition de matricules et identités | restreindre accès, anonymiser les exports publics |
| Élevée | Autorisations académiques non démontrées | seules routes comptes/profils | accès indu aux notes/classes possible | policies et tests d'isolation par rôle |
| Moyenne | Mots de passe temporaires d'import | script `009_import_etudiants...sql` | comptes non conformes en production | première connexion obligatoire et rotation |
| Moyenne | Crédits Master incohérents | INF461, INF561, INF571 | calculs et publication erronés | arbitrage documentaire avant activation |
| Faible | Avertissements de test UI | `widget_test.dart` | tests moins robustes | `ensureVisible` avant tap |

Aucun secret, mot de passe ou token n'est reproduit dans ce rapport.
