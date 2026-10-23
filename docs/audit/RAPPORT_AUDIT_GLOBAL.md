# Rapport d'audit global — Phase 1

## Synthèse

Le projet possède une base académique PostgreSQL documentée et alimentée, un frontend Flutter responsive testé et un backend Laravel/Sanctum conservé dans l'ancienne version. La faiblesse principale est l'absence d'un backend Laravel actif à la racine et l'absence totale de connexion API dans Flutter : le frontend reste un prototype piloté par `DemoStore`.

## Tableau de synthèse

| Domaine | État actuel | Problèmes | Priorité |
|---|---|---|---|
| PostgreSQL | modèle riche et données importées | vérification live non disponible, 3 écarts de crédits | élevée |
| API Laravel | authentification/comptes dans sauvegarde | backend non canonique, endpoints métier absents | critique |
| Authentification | Sanctum présent côté sauvegarde | Flutter non connecté | critique |
| Autorisations | middleware de rôle présent | isolation académique non démontrée | élevée |
| Flutter | 13 tests et build Web réussis | `DemoStore`, pas d'API | critique |
| Notes | simulation enseignant | saisie réelle et workflow absent côté API | élevée |
| Bulletins | tables et écrans partiels | génération/consultation API absente | élevée |
| Rattrapages | tables et écran démonstratif | endpoints absents | moyenne |
| Sécurité | base Sanctum et rôles dans sauvegarde | données personnelles dans exports/commits | élevée |
| Tests | Flutter validé | backend et intégration non testés | élevée |

## Fonctionnalités réellement opérationnelles

- navigation Flutter par rôle ;
- responsive et thème clair/sombre ;
- calculs et transitions de démonstration en mémoire ;
- catalogue et inscriptions chargés dans PostgreSQL selon les scripts précédents ;
- authentification Laravel dans le code sauvegardé, non intégrée au frontend actuel.

## Fonctionnalités absentes ou partielles

API académique, authentification Flutter, affectations réelles, notes et bulletins réels, requêtes/rattrapages API, publication serveur, calculs LMD officiels et autorisations fines.

## Décisions à obtenir

1. emplacement canonique du backend Laravel ;
2. politique de confidentialité des CSV et du dépôt GitHub ;
3. règles officielles de coefficients, arrondis, GPA/MGP et admission ;
4. correction documentaire des crédits `INF461`, `INF561`, `INF571`.

## Rapports détaillés

- `01_inventaire_projet.md`
- `02_audit_postgresql.md`
- `03_audit_backend_laravel.md`
- `04_audit_frontend_flutter.md`
- `05_audit_regles_metier.md`
- `06_rapport_tests.md`
- `07_securite_et_risques.md`
- `08_plan_execution.md`

Phase 1 terminée. Aucune modification applicative ou de données n'a été réalisée pendant l'audit.
