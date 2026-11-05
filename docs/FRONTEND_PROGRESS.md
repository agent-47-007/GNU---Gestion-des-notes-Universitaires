# État du client GNU

**Mise à jour : 3 novembre 2026.** Le porteur du projet confirme l’acceptation des parcours fonctionnels décrits ci-dessous. Les tests automatisés locaux sont également passés. Le déploiement sur l’infrastructure de l’établissement est suivi séparément dans [l’état de livraison](audit/09_validation_production.md).

## Authentification et socle

- [x] Connexion API et gestion de session par rôle
- [x] Inscription publique désactivée; création de comptes contrôlée par l’établissement ou portail de test local
- [x] Autorisations et erreurs API contrôlées côté serveur
- [x] Client Flutter connecté à l’API Laravel
- [x] Interface utilisable en navigateur mobile; session LAN de test compatible HTTP privé

## Espace étudiant

- [x] Tableau de bord, profil et notifications
- [x] Inscriptions pédagogiques et soumission
- [x] Résultats publiés, aperçus provisoires autorisés et bulletins
- [x] Requêtes, justificatifs, rattrapages
- [x] Téléchargement/impression du relevé

## Espace enseignant

- [x] Affectations et étudiants du périmètre
- [x] Configuration des plans et proposition de profil UE
- [x] Carnet, saisie/import et transmission des notes
- [x] Vérification ou retour des numérisations
- [x] Requêtes affectées, résultats provisoires et notes de rattrapage

## Espace agent

- [x] Périmètre départemental et tableau de bord
- [x] Structure, catalogue, classes, comptes et affectations
- [x] Revue des inscriptions et routage des requêtes
- [x] Numérisation/retour des notes et journal d’audit
- [x] Aperçus, habilitation et publication des résultats
- [x] Sessions et opportunités de rattrapage

## Règles et contrôles

- [x] Pondérations validées à 100 %, notes sur 20, absences et notes manquantes distinctes
- [x] Rattrapage de 0 inclus à 10 exclu; obligatoire jusqu’à 7,5 inclus, facultatif au-dessus; une session
- [x] Tests Flutter et Laravel locaux

Les cases reflètent l’état fonctionnel accepté par le porteur et ne signifient pas que l’application est déployée sur le serveur de l’établissement. Les domaines HTTPS, secrets, comptes et base de recette restent propres à l’environnement de livraison.
