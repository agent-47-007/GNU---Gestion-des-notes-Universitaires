# Cas d’utilisation GNU et scénarios de test

**Périmètre :** parcours exposés par l’API Laravel et l’application Flutter du dépôt.  
**Référence fonctionnelle :** routes API, contrôleurs, règles métier et guide de tests manuels présents dans le projet.  
**État des scénarios :** propositions de recette à exécuter; ce document ne constitue pas un procès-verbal de tests.

## 1. Acteurs

| Acteur | Description et périmètre |
|---|---|
| Visiteur / demandeur | Utilisateur non connecté. Consulte les choix académiques nécessaires au formulaire et soumet une demande de compte. Il ne reçoit pas un compte actif automatiquement. |
| Étudiant | Consulte et met à jour son propre espace étudiant, soumet ses choix d’inscription, consulte ses informations académiques et résultats, dépose des requêtes et candidate au rattrapage. |
| Enseignant | Consulte les classes et affectations qui le concernent, prépare les évaluations, saisit ou importe les notes, les transmet et traite les requêtes qui lui sont attribuées. |
| Agent | Gère les données académiques, comptes, affectations et dossiers de son ou ses départements; contrôle les inscriptions, les notes transmises, publications, sessions et journaux. |
| Administrateur système | **Habilitation portée par un compte Agent**, pas un quatrième rôle dans l’énumération des rôles. Peut gérer les habilitations d’administration système. Les droits de publication sont également distincts du rôle Agent. |
| Services GNU | Acteurs secondaires automatiques : API, base de données, calcul académique et notifications déclenchées par les opérations. Ils n’ouvrent pas de session utilisateur. |

## 2. Matrice de couverture

| Domaine | Visiteur | Étudiant | Enseignant | Agent | Agent habilité administrateur système |
|---|:---:|:---:|:---:|:---:|:---:|
| Demande de compte | ✓ |  |  | Examiner / décider |  |
| Authentification, profil, référentiels | ✓ | ✓ | ✓ | ✓ | ✓ |
| Inscriptions pédagogiques |  | Soumettre |  | Examiner / décider |  |
| Notes, évaluations, transmissions |  | Consulter | Configurer / saisir / transmettre | Numériser / retourner / publier |  |
| Requêtes |  | Créer / suivre | Traiter celles attribuées | Router / suivre |  |
| Rattrapages et sessions |  | Candidater / consulter | Préparer les épreuves / saisir les notes | Programmer / administrer |  |
| Résultats et bulletins |  | Consulter ceux publiés | Aperçu provisoire | Aperçu / publier / historique | Peut accorder des droits de publication |
| Structure, catalogue, comptes et affectations |  |  | Proposer des enseignements | Gérer dans le périmètre départemental | Gérer les habilitations d’administrateur système |

## 3. Préparer la recette

1. Utiliser une base isolée de recette et des données fictives clairement identifiées; ne pas publier de résultats d’une classe réelle.
2. Préparer un visiteur, un étudiant, un enseignant, un agent du département A, un agent du département B et, si nécessaire, un agent administrateur système.
3. Préparer une classe de test, des UE/EC, des inscriptions, des affectations et des notes cohérentes avec les règles de la formation. Prévoir une affectation hors périmètre pour les essais de refus.
4. Vérifier chaque scénario par l’interface et, si utile, par l’API authentifiée. Un refus d’accès attendu compte comme un résultat correct.
5. Consigner le résultat réel. Ne pas passer un scénario à « réussi » sur la seule base du résultat attendu écrit ici.

### Fiche de résultat à recopier

```text
ID scénario :
Date / version testée :
Acteur et compte de test :
Préconditions / données :
Étapes réellement effectuées :
Résultat attendu :
Résultat obtenu :
Statut : RÉUSSI / ÉCHOUÉ / BLOQUÉ / NON EXÉCUTÉ
Preuve (capture, réponse API, référence) :
Anomalie / suivi :
```

## 4. Scénarios transversaux

| ID | Cas d’utilisation et scénario | Résultat attendu |
|---|---|---|
| TR-01 | **Se connecter** — Avec un compte actif de chaque rôle, saisir le bon login et mot de passe; recommencer avec un mauvais mot de passe. | Connexion réussie et ouverture de l’espace correspondant; identifiants erronés refusés sans révéler de secret. |
| TR-02 | **Refuser un compte inactif** — Tenter de se connecter puis d’utiliser un jeton existant après désactivation du compte. | Accès refusé; un compte inactif ne peut pas continuer à utiliser l’API. |
| TR-03 | **Respecter les rôles et périmètres** — Sans session appeler une route protégée; avec chaque rôle appeler une route réservée à un autre rôle; avec un Agent A demander une ressource du département B. | Non authentifié : refus. Mauvais rôle : refus. Hors périmètre : ressource absente ou action refusée, sans fuite de données. |
| TR-04 | **Consulter les référentiels** — Après connexion, consulter années, filières, spécialités, niveaux, semestres, classes, UE et EC. | Référentiels cohérents et filtrés selon les paramètres/périmètres prévus; appel anonyme refusé. |
| TR-05 | **Consulter et modifier son profil** — Lire son profil, modifier les champs autorisés, puis essayer de modifier le profil d’un autre utilisateur ou d’un rôle différent. | Seules les données personnelles autorisées du compte connecté changent. |
| TR-06 | **Changer le mot de passe** — Modifier avec le mot de passe actuel et une confirmation correcte; essayer un mot de passe actuel incorrect ou une confirmation divergente; réutiliser l’ancien jeton/session selon la politique appliquée. | Mise à jour confirmée dans le premier cas; validation/refus dans les autres; la règle de révocation des sessions est respectée. |
| TR-07 | **Fermer une session** — Se déconnecter d’un appareil, puis utiliser le jeton; utiliser ensuite la fermeture de toutes les sessions et réessayer un autre jeton. | Jeton révoqué après la fermeture individuelle; tous les jetons révoqués après la fermeture globale. |
| TR-08 | **Lire une notification** — Ouvrir une notification, la marquer comme lue, puis essayer de modifier la notification d’un autre utilisateur. | État de lecture mis à jour uniquement pour le destinataire autorisé. |

## 5. Visiteur et demandeur de compte

| ID | Cas d’utilisation et scénario | Résultat attendu |
|---|---|---|
| VI-01 | **Soumettre une demande de compte** — Charger les départements et choix académiques; envoyer une demande Étudiant avec une classe cohérente, puis une demande Enseignant ou Agent sans année/classe; consulter ensuite la demande comme Agent habilité du bon département. | La demande valide est créée en attente, sans ouvrir de session ni créer automatiquement un compte actif. Les données invalides ou incohérentes, mot de passe trop court/non confirmé, login ou identifiant de profil déjà utilisé sont refusés. L’Agent autorisé peut la retrouver pour décision. |

## 6. Étudiant

| ID | Cas d’utilisation et scénario | Résultat attendu |
|---|---|---|
| ET-01 | **Consulter et soumettre ses inscriptions pédagogiques** — Afficher les UE admissibles, enregistrer une sélection, recharger, puis soumettre une sélection conforme aux règles du semestre; recommencer avec un nombre invalide, une UE non proposée ou une inscription déjà traitée. | Les choix valides persistent et la soumission passe en attente de validation. Sélection non conforme, hors catalogue ou doublon refusé avec indication claire. |
| ET-02 | **Consulter sa fiche académique** — Afficher sa fiche/relevé, télécharger le document, puis tenter de lire la fiche d’une autre inscription. Si l’import de fiche est activé, importer un fichier conforme puis un fichier invalide. | Fiche propre à l’étudiant, téléchargement correct; accès à autrui refusé. Import valide reconnu et fichier invalide rejeté sans altérer la fiche. |
| ET-03 | **Consulter ses résultats provisoires** — Ouvrir les résultats alors qu’une évaluation est incomplète, puis après saisie/transmission de notes. | Résultats identifiés comme provisoires; note manquante conservée comme manquante/en attente et jamais convertie silencieusement en zéro. |
| ET-04 | **Consulter les résultats publiés et bulletins** — Ouvrir un bulletin publié par période, télécharger/archiver son PDF, l’imprimer et essayer l’identifiant d’un bulletin appartenant à un autre étudiant. | Seules les publications officielles disponibles pour le compte sont visibles; le document téléchargé correspond à la bonne période/version; accès à autrui refusé. |
| ET-05 | **Consulter PV et évaluations manquantes** — Afficher les PV d’évaluations et la liste des évaluations manquantes; comparer avec les évaluations de sa classe. | Les informations correspondent à la classe et aux évaluations concernées, sans exposer les dossiers d’autres étudiants. |
| ET-06 | **Créer et suivre une requête** — Créer une requête académique, joindre un justificatif si le type le permet, consulter le statut, télécharger le justificatif et vérifier le résultat après routage/traitement enseignant. | Requête créée pour l’étudiant connecté; pièce disponible seulement aux acteurs autorisés; statut et décision actualisés après traitement. Type/champs/fichier invalides et ressource d’un autre étudiant refusés. |
| ET-07 | **Consulter les rattrapages et candidater** — Avec des notes test à 0, 7,5, juste au-dessus de 7,5, juste en dessous de 10 et à 10, consulter l’admissibilité; candidater une fois puis répéter. | Admissible si `0 ≤ note < 10`; obligatoire jusqu’à `7,5` inclus, facultatif au-dessus; note de 10 non admissible. Une seule session/candidature conforme aux règles est acceptée; doublon et candidat non admissible refusés. |
| ET-08 | **Recevoir les notifications** — Provoquer une décision d’inscription, requête ou publication sur le compte de test, consulter et marquer l’avis comme lu. | Notification pertinente visible pour son destinataire; état lu conservé après rechargement. |

## 7. Enseignant

| ID | Cas d’utilisation et scénario | Résultat attendu |
|---|---|---|
| EN-01 | **Consulter les salles et rejoindre une classe** — Afficher les classes, demander l’accès à une classe ouverte, consulter l’effectif et exporter la liste Excel; recommencer avec une classe hors périmètre ou fermée. | Seuls les niveaux/classes autorisés sont visibles; adhésion conforme enregistrée, accès non autorisé refusé; export cohérent avec l’effectif. |
| EN-02 | **Proposer une affectation d’enseignement** — Choisir des UE/EC disponibles dans une salle, soumettre la proposition et consulter son état; essayer un EC incompatible, dupliqué ou hors classe. | Proposition valide apparaît en attente côté enseignant et dans la file de l’Agent du département concerné; les incompatibilités sont refusées. |
| EN-03 | **Consulter ses affectations et étudiants** — Ouvrir ses affectations actives, consulter l’effectif/fiche académique d’un étudiant rattaché, puis demander les données d’une affectation inactive ou d’un étudiant hors affectation. | Seules les données de ses affectations et étudiants autorisés sont retournées; accès indu refusé. |
| EN-04 | **Configurer le plan d’évaluation** — Ajouter les épreuves et pondérations d’une affectation; soumettre un total de 100 %, un total différent, une pondération négative ou une évaluation répétée; modifier la planification d’une épreuve. | Plan valide enregistré/versionné et audité. Pondérations invalides refusées. Les statuts/dates d’évaluation suivent les règles de planification. |
| EN-05 | **Proposer le profil d’évaluation d’une UE** — Soumettre une proposition autorisée pour son affectation, puis une proposition non autorisée ou incompatible avec la structure des évaluations. | Proposition valide transmise au circuit de décision; toute modification hors affectation ou incompatible est refusée. |
| EN-06 | **Consulter et exporter le carnet** — Ouvrir le carnet de l’affectation, générer son export, vérifier étudiants et colonnes d’évaluation. Tester une autre affectation. | Carnet et export cohérents avec l’affectation autorisée; aucun étudiant ou résultat d’un autre périmètre. |
| EN-07 | **Saisir et corriger des notes** — Enregistrer des notes valides sur 20, une absence, et laisser une note manquante; sauvegarder et recharger. Tester note négative, supérieure à 20, étudiant inconnu et retrait logique d’une note. | Notes valides persistées; absence et note manquante restent distinctes; valeurs/hors-périmètre refusées; retrait logique audité sans effacement de l’historique. |
| EN-08 | **Saisir une note pour un étudiant non inscrit** — Depuis le flux dédié, sélectionner un étudiant externe autorisé pour l’affectation, saisir une note et vérifier son statut; tenter un étudiant non admissible ou une affectation différente. | Le workflow externe autorisé conserve la note et son statut spécifique; les identités et affectations non autorisées sont refusées. |
| EN-09 | **Importer des notes** — Télécharger le modèle, préparer un fichier valide et consulter son aperçu avant import; tester fichier mal formé, matricule inconnu, doublon ou note hors barème; tester l’import de grille de classe en aperçu. | Modèle/aperçu identifient clairement les lignes acceptées et rejetées; seuls les résultats confirmés et valides sont appliqués; fichier invalide ne modifie pas les notes. |
| EN-10 | **Transmettre les notes et traiter un retour** — Transmettre un jeu de notes complet, consulter son PV; côté Agent, numériser puis publier ou retourner pour correction; côté Enseignant, consulter le retour, corriger et retransmettre. | Transmission suit les états attendus et conserve son PV/audit; publication impossible avant les contrôles requis; retour contient un motif et permet une correction traçable. |
| EN-11 | **Consulter les bulletins provisoires** — Ouvrir les aperçus pour son affectation avant et après validation des notes. | Calculs provisoires reflètent les notes connues, distinguent les manquantes, appliquent les règles académiques et restent identifiés comme non publiés. |
| EN-12 | **Traiter une requête attribuée** — Ouvrir une requête routée à cet enseignant, saisir une décision/réponse, puis essayer de traiter une requête d’un autre enseignant. | Décision enregistrée et visible par l’étudiant; requête non attribuée/hors périmètre non modifiable. |
| EN-13 | **Préparer un rattrapage et saisir les notes** — Consulter les candidats, programmer une session, créer les évaluations permises, saisir et transmettre les notes. Tester une session close, une note invalide et un étudiant non admissible. | Une seule session conforme; seuls les candidats admissibles et évaluations autorisées sont traités; changements après clôture et données invalides refusés. |
| EN-14 | **Consulter ses notifications et profil** — Consulter les avis de transmission, requête ou affectation, marquer lus et mettre à jour son profil. | Avis et profil rattachés au seul compte enseignant connecté. |

## 8. Agent

| ID | Cas d’utilisation et scénario | Résultat attendu |
|---|---|---|
| AG-01 | **Consulter le tableau de bord départemental** — Ouvrir le tableau de bord avec l’Agent A, comparer ses indicateurs aux données de son département, puis faire le même contrôle avec l’Agent B. | Chaque tableau de bord et chaque liste ne contiennent que les données des départements attribués; l’absence d’habilitation de publication est signalée. |
| AG-02 | **Administrer la structure académique** — Consulter puis créer/modifier les entités autorisées (université, faculté, département, filière, spécialité, niveau), générer les niveaux d’une filière et charger un logo valide. Tester parent invalide et fichier non image/trop volumineux. | Entités valides visibles dans la hiérarchie; génération sans doublon indu; rattachement parent vérifié; logo conforme accepté et fichier invalide refusé. Toute opération reste dans les permissions du rôle/périmètre. |
| AG-03 | **Gérer classes et catalogue UE/EC** — Créer une classe pour une année/niveau, créer une UE et ses EC, modifier l’état brouillon/actif/archivé et le profil d’évaluation. Tester code en doublon, niveau/catégorie incompatibles et crédits invalides. | Données cohérentes créées; contraintes de catalogue et unicité appliquées; seules les UE admissibles sont proposées aux inscriptions. |
| AG-04 | **Consulter et gérer les comptes** — Rechercher les comptes du département, corriger les champs permis, désactiver/réactiver un compte de test et le supprimer si autorisé. Essayer de suspendre son propre compte ou un compte d’un autre département. | Changements autorisés tracés; désactivation révoque les sessions; opérations interdites et hors périmètre refusées. |
| AG-05 | **Examiner une demande de compte** — Ouvrir une demande en attente et l’approuver ou la rejeter avec motif; refaire la demande dans un second département et tenter de la décider avec l’Agent A; traiter deux fois la même demande. | Compte créé/activé uniquement après approbation et rattachement correct; rejet motivé conservé; hors périmètre et demande déjà traitée refusés. |
| AG-06 | **Décider une proposition d’affectation** — Examiner la proposition EN-02, l’accepter ou la refuser avec motif; vérifier ensuite l’affectation côté enseignant. | Décision et motif persistés; acceptation crée/rend visible une affectation cohérente; proposition hors périmètre ou déjà décidée refusée. |
| AG-07 | **Créer et administrer une affectation** — Affecter un enseignant, EC et classe compatibles; désactiver/réactiver l’affectation; désigner le responsable de notes. Tester combinaison incompatible ou utilisateur non enseignant. | Affectation cohérente créée et visible par les deux rôles; états et habilitation de saisie reflétés dans le carnet; combinaisons invalides refusées. |
| AG-08 | **Valider une inscription pédagogique** — Consulter la file, accepter ou refuser une inscription avec motif, vérifier la notification et l’état côté étudiant; décider à nouveau une demande traitée. | État étudiant actualisé et décision auditée/notifiée; transition invalide ou répétée refusée. |
| AG-09 | **Consulter une fiche académique** — Télécharger la fiche d’une inscription du département; essayer l’identifiant d’une autre classe ou d’un département différent. | Document exact téléchargé uniquement pour un dossier du périmètre autorisé. |
| AG-10 | **Router une requête vers un enseignant** — Affecter une requête au titulaire concerné, la vérifier côté enseignant et étudiant; tenter de choisir un enseignant sans affectation pertinente. | Requête visible dans les espaces concernés; attribution limitée aux enseignants reliés à la classe/UE; choix non pertinent refusé. |
| AG-11 | **Contrôler et numériser une transmission de notes** — Ouvrir la file, télécharger le PV, saisir/confirmer les notes numérisées, puis retourner une transmission au besoin; vérifier le motif et le statut côté enseignant. | Données de transmission exactes; actions horodatées/auditées; retour motivé; publication bloquée tant que les conditions de validation ne sont pas remplies. |
| AG-12 | **Prévisualiser, publier et consulter les bulletins** — Ouvrir aperçu, PV UE et PV requêtes; vérifier complétude, MGP, notes manquantes et décisions. Avec compte habilité et classe de recette, publier une période; ouvrir historique, télécharger la version choisie et exporter l’Excel correspondant. | Aperçu n’est pas publié. Publication officielle exige règles approuvées, notes complètes et habilitation distincte; numéro de version/historique conservé; PDF/Excel correspondent exactement à la version et à la période sélectionnées. Agent sans habilitation et publication incomplète sont refusés. |
| AG-13 | **Gérer examens normaux et sessions de rattrapage** — Programmer une date/salle pour une évaluation normale; créer/ouvrir/fermer une session de rattrapage; consulter les opportunités/candidats et vérifier les conflits d’horaire. | Planning valide enregistré; créneaux en conflit ou ressources invalides refusés; transitions d’état et admissibilités respectées; session close non modifiable comme ouverte. |
| AG-14 | **Consulter l’audit et ses notifications** — Après plusieurs opérations ci-dessus, filtrer/consulter le journal et ses horodatages; marquer une notification lue; chercher des actions d’un autre département. | Auteur, action, date et motif pertinents consignés; vue limitée au périmètre; notification de l’autre compte inaccessible. |
| AG-15 | **Exporter résultats publiés** — Télécharger le classeur d’une classe/période/version, comparer les onglets et nombres avec les bulletins archivés; essayer une version inconnue ou une classe hors périmètre. | Export cohérent avec la publication historisée; version inconnue, non publiée ou hors périmètre refusée. |

## 9. Agent habilité administrateur système

| ID | Cas d’utilisation et scénario | Résultat attendu |
|---|---|---|
| AS-01 | **Lister les administrateurs système** — Depuis un Agent habilité, consulter les comptes administrateurs configurés/en base; refaire l’appel avec un Agent ordinaire. | L’habilité voit les comptes et leur source; l’Agent ordinaire reçoit un refus. |
| AS-02 | **Accorder une habilitation** — Pour un Agent actif rattaché à un département, fournir un motif valide; tester Agent inactif, non rattaché, compte non-Agent et motif trop court. | Habilitation accordée et auditée dans le cas valide; états invalides rejetés; compte configuré ou déjà habilité traité sans doublon. |
| AS-03 | **Révoquer une habilitation** — Révoquer les droits d’un autre Agent administrateur avec motif; tenter de révoquer ses propres droits, le dernier administrateur actif, ou un administrateur défini par configuration. | Révocation permise seulement si un administrateur actif reste et si la cible est révocable; auto-révocation et retrait du dernier administrateur refusés. |
| AS-04 | **Vérifier les droits avancés** — Accorder les droits administrateur système à un Agent de test puis vérifier son accès aux opérations globales et de publication; révoquer ensuite ses droits et répéter. | Les fonctions avancées sont accessibles pendant l’habilitation seulement; après révocation l’Agent revient aux permissions de son rôle et de son périmètre; aucune publication n’est créée par une tentative refusée. |

## 10. Scénarios de règles académiques à couvrir

Ces contrôles complètent les parcours ci-dessus et doivent être passés sur des données de recette.

| ID | Donnée frontière | Résultat attendu |
|---|---|---|
| REG-01 | Pondérations d’évaluation : total égal à 100 %, puis juste inférieur/supérieur à 100 %. | Seul le plan conforme est accepté. |
| REG-02 | Notes : 0, 10, 20, valeur négative, valeur supérieure à 20. | Valeurs de 0 à 20 acceptées selon le format autorisé; hors intervalle refusées. |
| REG-03 | Note absente versus absence officiellement saisie. | États distincts dans carnet, calcul progressif et bulletin; la note absente n’est pas assimilée à zéro. |
| REG-04 | Acquisition UE à 9,99 puis 10/20, sans compensation automatique entre UE. | Seuil appliqué à 10/20; pas de compensation automatique non prévue. |
| REG-05 | Rattrapage à 0, 7,5, juste au-dessus de 7,5, juste sous 10 et à 10. | Admissibilité si `0 ≤ note < 10`; caractère obligatoire/facultatif conforme aux seuils décrits en ET-07. |
| REG-06 | Publication avec une note manquante, puis après complétude; publication avec Agent sans habilitation. | Publication incomplète ou non habilitée refusée; aucun bulletin officiel/version partielle ne doit être créé. |
| REG-07 | Étudiant avec MGP sous le seuil de réussite. | Bulletin produit si les données sont complètes, décision d’échec affichée conformément aux règles; le bulletin n’est pas supprimé. |

## 11. Critères de clôture de recette

- Chaque scénario est marqué **RÉUSSI**, **ÉCHOUÉ**, **BLOQUÉ** ou **NON EXÉCUTÉ** avec une preuve ou une explication.
- Les refus de rôle, de périmètre, de validation et d’habilitation ont été testés, pas seulement le parcours nominal.
- Les transmissions, décisions, publications, versions et opérations sensibles ont laissé les traces attendues.
- Les scénarios de publication ont été exécutés exclusivement sur une base et une classe de recette, par un compte habilité.
- Les échecs sont associés à une anomalie reproductible; les corrections sont suivies par un nouvel essai.
