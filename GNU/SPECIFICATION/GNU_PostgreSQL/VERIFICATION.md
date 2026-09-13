# Vérification de la livraison GNU PostgreSQL

Le script final de création et les tests ont été exécutés avec succès sur PostgreSQL 18.3 embarqué dans PGlite 0.5.8. La syntaxe des deux lanceurs Bash a été vérifiée avec `bash -n`, et l’aide de l’installateur a été exécutée.

## Résultats constatés

- Installation atomique réussie : 29 tables métier, 61 clés étrangères, 116 triggers applicatifs, 27 fonctions et 4 vues.
- Les scénarios SQL du fichier `002_tests.sql` passent, y compris les écritures via un rôle applicatif distinct du propriétaire.
- Bulletin fictif normal : MGP annuelle 2,40, admission.
- Après remplacement des seules SN concernées : MGP 2,61.
- Absence au rattrapage : UE portant EL, MGP affichée 2,13, échec.
- SN de rattrapage plus basse : 20 remplace 34, EC 27 et UE 49.
- Refus des notes hors bornes, NaN et infinis; zéro accepté.
- Refus d’une UE active vide, d’une troisième matière et de changements des lignes d’un plan actif.
- Historique automatique de note et décision de jury; suppression directe interdite.
- Un rôle non propriétaire ne peut pas insérer directement une publication ni modifier l’historique. Il peut appeler la fonction de publication avec le contexte d’un agent actif.
- Un rattrapage consommé ne peut être remis à zéro; une seconde candidature de même portée est refusée.
- Une requête d’absence sans pièce est refusée lors du contrôle différé.
- La fonction de délai accepte exactement 48 h et refuse une microseconde au-delà ou une date antérieure à publication.
- Une republication permet une requête sur l’EC corrigé et refuse la réouverture sur un EC inchangé.
- Les jours ouvrables excluent samedi, dimanche et les fermetures fournies; aucune relance lorsque toutes les notes sont validées.
- Une UE EL se reprend l’année suivante; une UE insuffisante ne peut pas être déclarée conservée.
- Après annulation des fixtures, le schéma ne contient aucun utilisateur de démonstration.
- Une seconde installation est refusée avec l’erreur de schéma préexistant; le schéma installé est conservé.

## Limites de ces essais

Le serveur PostgreSQL natif n’était pas installé dans l’environnement de travail. Le lanceur Bash n’a donc pas ouvert une connexion réseau via `psql` ici; sa syntaxe et son chemin d’aide ont été contrôlés, et le SQL a été exécuté via PGlite.

Le minimum annoncé PostgreSQL 14 repose sur les fonctionnalités utilisées; l’exécution constatée porte sur PostgreSQL 18.3 embarqué. Exécuter `bash installer.sh --tests` sur la version native choisie avant intégration Laravel. Les tests du rôle temporaire nécessitent le droit de créer un rôle dans la base de test.

Les essais ne couvrent pas une charge de production, des transactions réellement concurrentes sur plusieurs connexions, une restauration de sauvegarde, les autorisations HTTP, le stockage externe des justificatifs ni les envois de notifications. Ces vérifications restent à réaliser avec le backend et le serveur de déploiement.
