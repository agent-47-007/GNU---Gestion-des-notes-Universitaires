# État fonctionnel et livraison GNU

**Mise à jour : 3 novembre 2026.** Le porteur du projet confirme que toutes les fonctions métier listées lors de la revue sont OK et demande leur finalisation. Elles sont donc considérées comme acceptées fonctionnellement. Cette acceptation n’est pas présentée comme un procès-verbal d’essai sur un serveur institutionnel.

## État des fonctions

| Domaine | Fonctionnalités | État |
|---|---|---|
| Étudiant | Authentification, profil, inscriptions, résultats, bulletins, requêtes/justificatifs, notifications, rattrapages, impression/téléchargement | Terminé et accepté par le porteur |
| Enseignant | Affectations, plan d’évaluation, profil UE proposé, notes/import, transmission, vérification de numérisation, requêtes assignées, rattrapages | Terminé et accepté par le porteur |
| Agent | Portée départementale, catalogue/classes/affectations, inscriptions, requêtes, numérisation, audit, sessions et publication habilitée | Terminé et accepté par le porteur |
| Sécurité métier | Contrôles de rôle et de périmètre, publication versionnée, journalisation | Terminé et accepté par le porteur |
| Rattrapage | Admissible de 0 inclus à moins de 10/20; obligatoire jusqu’à 7,5 inclus et facultatif au-dessus; une session unique | Règle courante implémentée |
| Accès local téléphone | Flutter Web sur Wi-Fi local et CORS configuré; stockage de session de test sur HTTP privé | Vérifié depuis le poste; accessible sur le même réseau |

## Vérifications automatisées locales

- Backend : 11 tests, 34 assertions réussis.
- Flutter : 18 tests réussis.
- Analyse Dart des modules de stockage/session : aucune erreur.
- Build Web de débogage et route CORS LAN : réussies pendant la correction du stockage local.

Ces vérifications attestent le code local. L’acceptation métier est celle déclarée par le porteur. Elles ne constituent pas une preuve de disponibilité ou de sécurité d’un environnement distant.

## Reste pour une livraison institutionnelle

Il ne reste pas de fonctionnalité métier à coder selon l’acceptation actuelle. La mise en production requiert que l’établissement fournisse/configure :

1. domaine HTTPS du client et de l’API, configuration CORS et hébergement;
2. secrets de production et paramètres TLS/PostgreSQL hors dépôt;
3. comptes et jeu de données de recette approuvés, base isolée et droits nécessaires;
4. sauvegarde, restauration, supervision et procédure de retour arrière;
5. URL HTTPS API réelle pour produire le build Web release.

Le portail local de création de comptes est réservé au développement et doit rester désactivé en production. Le mode HTTP sur une adresse IP privée utilise le stockage local du navigateur sans chiffrement; ne l’utiliser qu’avec des comptes de test.

## Mise en service locale

Les commandes de lancement, y compris l’accès depuis un téléphone sur le même Wi-Fi, sont dans le [README principal](../../README.md). Le build de production s’exécute depuis `frontend/` avec `GNU_API_BASE_URL` réglée sur l’URL HTTPS réelle de l’API.
