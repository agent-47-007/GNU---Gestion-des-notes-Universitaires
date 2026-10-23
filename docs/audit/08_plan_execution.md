# 08 — Plan d'exécution post-audit

| ID | Tâche | Priorité | Dépendances | Critère de validation |
|---|---|---|---|---|
| P2-01 | établir le backend Laravel canonique et sa configuration | critique | décision d'arborescence | `artisan route:list` et connexion PostgreSQL documentés |
| P2-02 | exposer authentification et profils pour Flutter | critique | P2-01 | tests Sanctum et isolation des rôles |
| P2-03 | créer endpoints académiques en lecture | élevée | modèle PostgreSQL validé | UE/classes/inscriptions retournées en JSON |
| P3-01 | créer client HTTP et gestion session Flutter | critique | P2-02 | connexion réelle et expiration gérée |
| P3-02 | remplacer DemoStore écran par écran | élevée | P2-03 | aucun écran ciblé ne dépend de données fictives |
| P4-01 | affectations, évaluations et notes | élevée | P3 | tests enseignant classe/EC |
| P5-01 | calculs, bulletins, publication, requêtes et rattrapages | élevée | P4 | parcours complet auditable |
| P6-01 | tests intégration, sécurité, sauvegarde et livraison | élevée | P2--P5 | CI et procédure de restauration validées |

## Première tâche recommandée

La première tâche de développement est `P2-01` : rendre le backend Laravel canonique et vérifier sa connexion au schéma `gnu` en lecture seule. Sans cette décision, toute intégration Flutter risquerait de cibler une sauvegarde ou une base différente.
