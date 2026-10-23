# 05 — Audit et règles métier retenues

Le 15 octobre 2026, l'utilisateur a validé les propositions de règles du
compte-rendu. Elles sont enregistrées ci-dessous comme règles applicatives
approuvées pour GNU. Leur approbation ne remplace pas les vérifications de
conformité exigées par le règlement officiel de l'établissement.

| Règle retenue | Valeur | État d'implémentation |
|---|---|---|
| Périmètre enseignant | Affectations actives propres à l'enseignant, pour classe et matière | Lecture des affectations et plans exposée par API avec filtrage serveur. Saisie/transmission non reliée à la table historique des notes, dont le schéma n'est pas disponible dans le dépôt |
| Périmètre agent | Département attribué; périmètre transversal réservé au rôle distinct d'administrateur système | Bloqué : aucun rattachement agent-département ni rôle administrateur système connu dans le schéma accessible |
| Plan d'évaluation | Plan rattaché à l'affectation; pondérations totalisant 100 %; après transmission, modification interdite ou nouvelle version auditée | Contrôle de total et lecture versionnée codés. Écriture/versionnement et verrouillage à transmission bloqués par l'absence du schéma métier lisible |
| Barème | Notes sur 20; calcul pondéré; arrondi final à 2 décimales | Moteur de règle et tests unitaires ajoutés; aucune chaîne de persistance de notes disponible |
| Absence / note manquante | Statuts explicites `ABSENT` et `MANQUANTE`; aucun zéro implicite | Garde implémentée dans le moteur de calcul; propagation à la note historique et aux bulletins bloquée |
| Acquisition d'une UE | Acquise à partir de 10/20; pas de compensation automatique entre UE ou semestres | Règle intégrée au calcul isolé; traitement des crédits et calcul d'un bulletin officiel non implémentés |
| Rattrapage | Admissible si note publiée comprise entre 5/20 inclus et 10/20 exclu; une seule session | Seuil configuré à 5/20, conversion des anciennes notes `/100` pour la lecture; aucun endpoint de candidature/planification et aucune garantie DB de session unique |
| Transmission des notes | Brouillon puis transmission; verrouillage après transmission; correction sous nouvelle version avec historique | Bloqué : colonnes et contraintes de `gnu.note` non présentes dans le dépôt; aucune route métier de note |
| Contrôle / publication | Agent contrôle et accepte/retourne avec motif; rôle distinct de responsable pédagogique publie; bulletin publié immuable, correction = nouvelle version | Bloqué : états, journal, permissions et relations des tables historiques non décrits; la revue d'inscription agent reste `503` faute de périmètre |
| Requêtes | Contestation/absence de note à l'enseignant affecté; requêtes administratives à la cellule; décision motivée | Blocage de persistance et transitions : le formulaire étudiant n'identifie pas toujours l'EC ciblé et le schéma de `decision_requete` n'est pas accessible pour validation |
| Comptes étudiants | Pas d'auto-inscription; création depuis une source de scolarité vérifiée, activation à usage unique avec expiration, audit et révocation | Auto-inscription désactivée; procédure reste à fournir par l'établissement, dont la source de vérité et les opérateurs habilités |

## Fondements conservés de l'audit initial

| Règle existante | Sources | Constat |
|---|---|---|
| 1 à 2 EC par UE active | contrainte et activation `006_import_ec_catalogue.sql` | Définie dans les scripts de catalogue |
| Crédits UE et EC distincts | colonnes documentées `credit_ue`, `credit_matiere` | Ne pas utiliser les crédits comme coefficients de notes |
| Pondération actuelle CC/examen | données de classe non vérifiées | Les anciens écrans `DemoStore` ne constituent pas une règle opérationnelle |
| MGP, admission et EL | non vérifiés sur base réelle | Pas de calcul ni décision officielle automatique ajouté |

## Configuration applicative

Les valeurs acceptées sont centralisées dans `backend/config/academic.php` :
total des pondérations 100, échelle 20, validation à 10, arrondi à deux
décimales, fenêtre de rattrapage `[5, 10[` et maximum d'une session. Aucun
paramètre d'environnement de seuil n'est nécessaire pour ces règles désormais
approuvées. Les règles ne sont pas encore reliées à la persistance des notes et
à la publication.

La base métier n'a pas répondu lors de l'inspection locale et son DDL n'est pas
versionné dans ce dépôt. Aucune migration de notes, publication, rôles ou
périmètres ne doit être exécutée avant d'obtenir une description vérifiée du
schéma et les droits de migration de la cible de test.
