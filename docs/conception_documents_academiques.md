# Conception des PV et bulletins GNU

## Objectif

Produire des documents imprimables et traçables à partir des inscriptions, évaluations, notes validées, décisions de requêtes et publications GNU. Les documents doivent conserver l’identité graphique des modèles UY1/FDS fournis, tout en séparant clairement les documents de travail des documents officiels.

## Modèles de référence et distinction des documents

- Le PV de CC fourni est la maquette de base des PV par évaluation. Le PV de TP reprend cette même maquette : seul le titre et le libellé de note changent. Le fichier fourni porte « CC » dans son nom mais affiche « Examen pratique (EP) » dans son titre intérieur ; les nouveaux PV doivent utiliser le libellé explicitement associé à l’évaluation GNU (CC, TP, TPE ou SN).
- Le PV SN fourni est un relevé collectif détaillé : étudiants, matricules, niveau, contributions des évaluations, total, décision et mention. Les colonnes de contribution doivent venir du barème effectif de l’UE, et non de valeurs codées en dur.
- Le PVR de jury des requêtes est un document collectif post-décision : notes par UE pour une cohorte, crédits, pourcentage de crédits capitalisés, MGP, décision, statistiques de réussite et visas du jury.
- Le document intitulé « Relevé de notes/Transcript » est le modèle du bulletin individuel. La fiche académique fournie est une fiche d’inscription et de quitus de paiement ; elle ne doit pas être confondue avec le bulletin.

## Documents à produire

### 1. PV par évaluation

Un document collectif par classe, UE/EC, semestre, année et évaluation : CC, TP, TPE, SN ou Rattrapage.

En-tête : République/Republic of Cameroon, Université de Yaoundé I, Faculté, département, filière, spécialité si applicable, niveau, code et intitulé UE/EC, semestre, année académique, date et référence du PV. Logo institutionnel issu de la structure configurée.

Table : numéro, matricule, noms et prénoms, niveau, note sur 20, situation/observation. Les notes absentes sont marquées EL selon la règle GNU ; une absence doit rester distincte d’une note non saisie. Les étudiants non autorisés ou dont l’inscription pose problème peuvent être signalés avec un motif contrôlé par la cellule.

Le PV de CC et celui de TP ont la même mise en page. Le TPE réutilise cette grille avec son propre intitulé. Le PV individuel d’évaluation affiche la note brute sur 20 ; il ne remplace pas le PV collectif récapitulatif SN.

### 2. PV SN / relevé collectif des résultats de l’UE

Une ligne par étudiant inscrit et validé dans l’UE. Le PV expose les contributions prévues au plan officiel : CC, TP ou TPE, puis SN. Pour chaque composante, afficher la contribution pondérée au total, et si la maquette l’exige, la note brute sur 20. Afficher ensuite total/100, décision, mention et observation.

Les pondérations sont calculées avec le profil validé de l’UE. Le modèle de règles actuellement codé distingue notamment CC+TP+SN, CC+TPE+SN et CC+SN ; une composante absente du profil n’est pas créée artificiellement. Le détail des pondérations et le total doivent être cohérents avec le calcul officiel GNU.

### 3. PV de rattrapage

Document collectif limité aux étudiants autorisés au rattrapage après la session normale SN. La ligne comprend leur matricule et identité, les composantes conservées (CC et TP/TPE si prévues), puis une colonne **RATTRAPAGE** à la place de **SN**. La note de rattrapage remplace la note SN dans le calcul final ; elle ne remplace ni le CC, ni le TP/TPE. Le PV affiche le total recalculé, la décision et la mention résultantes.

Pour l’audit interne, la valeur SN d’origine reste conservée dans GNU avec la décision et la date de substitution. La maquette imprimée porte la note de rattrapage comme composante retenue ; le détail historique peut être fourni en annexe réservée aux agents habilités si nécessaire. Les autres étudiants de la classe ne figurent pas dans ce PV.

### 4. PV récapitulatif de cohorte après jury

Document collectif à l’échelle d’un niveau/filière/spécialité, d’une année et d’une période. Il reprend la structure du PVR fourni : étudiants en lignes, UE en colonnes avec code, crédit et résultat retenu ; crédits capitalisés, total ou taux de crédits capitalisés, MGP, décision (admis/échec/autre décision institutionnelle), puis statistiques de cohorte et zones de visas.

Le PV récapitulatif est généré seulement à partir de bulletins figés/publications officielles et des décisions de jury validées. Une requête acceptée entraîne une nouvelle version de résultat traçable, sans écraser le procès-verbal antérieur. L’en-tête mentionne explicitement la session et la date du jury.

### 5. PV de requêtes après jury

Document collectif réservé au jury et aux responsables habilités. Il contient une fiche par requête examinée : référence, étudiant/matricule, niveau/filière, UE/EC et évaluation contestée, catégorie, date, motif, pièces justificatives référencées, notes avant examen, avis de l’enseignant, contrôle de la cellule, décision motivée du jury, effet sur la note/le bulletin, auteur et horodatage.

La décision doit être explicite : accepter, rejeter, demander une pièce ou autoriser une correction/évaluation, selon les actions permises dans GNU. Le PV distingue les requêtes reçues, examinées, ajournées et décidées. Il ne doit pas exposer les pièces sensibles ni le dossier complet à toute la cohorte. Un relevé individuel de décision peut être transmis à l’étudiant ; le PV collectif complet reste confidentiel.

### 6. Bulletin individuel / relevé de notes

Un document par étudiant, inspiré du « Relevé de notes/Transcript » fourni. En-tête institutionnel et logo, numéro/référence du relevé, nom/prénoms, matricule, date/lieu de naissance si disponibles et autorisés, domaine, niveau, filière, spécialité, année académique.

Table des UE : code UE, intitulé, crédits, moyenne sur 100, mention, semestre, année, décision (capitalisée/non transférable/non capitalisée selon le référentiel officiel). Synthèse : crédits acquis/inscrits, MGP, décision annuelle/semestre, légende des mentions. Signatures et cachets suivent le modèle institutionnel configuré (président du jury et chef de département si requis). Le document ne contient que les données de l’étudiant concerné.

La fiche d’inscription académique/quitus est un formulaire distinct : identité, année, reçus de paiement, UE fondamentales/optionnelles, crédits et signatures de scolarité/étudiant. Elle peut être conçue séparément à partir de la fiche fournie, sans la présenter comme un relevé de notes.

## Cycle de vie et droits

1. L’enseignant saisit/import ses notes ; GNU conserve les notes et leur version en brouillon.
2. L’enseignant transmet chaque évaluation séparément. Le PV porte un état « Brouillon » ou « Transmis pour contrôle » et une référence de transmission.
3. La cellule vérifie la grille numérisée, corrige/retourne si besoin, puis valide. La copie contrôlée est rattachée à la transmission.
4. Les résultats provisoires restent clairement marqués provisoires. La cellule publie les notes après contrôles ; l’étudiant ne voit que ses propres notes.
5. Les PV SN, rattrapage et récapitulatif sont produits selon le niveau de validation requis et les règles officielles. Le bulletin individuel est disponible à l’étudiant après publication.
6. Une correction ou décision de requête crée une version suivante ; les versions antérieures, motifs, approbateurs, empreintes de fichiers et horodatages restent auditables.

Les signatures manuscrites sont représentées par des zones à signer. Un nom imprimé ou une image de signature ne vaut pas signature électronique. Les logos, cachets et signatures ne sont utilisés que s’ils sont fournis et autorisés par la structure concernée.

## Sources de données et cohérence

- Référentiel étudiant, inscription de classe et inscription UE : cohorte, matricule, identité, niveau, filière/spécialité.
- Catalogue UE/EC unique par niveau : codes, intitulés, crédits et semestre.
- Profil d’évaluation approuvé et plan actif : composantes et pondérations.
- Notes et situations : valeur, EL/absence, version, statut et évaluation source.
- Transmission, PV numérisé, contrôle cellule et publication : circuit, état et pièces.
- Requêtes et décisions : motif, pièces, décision, effet, acteur et audit.
- Bulletin figé : calcul officiel de l’EC/UE, crédits, MGP et décision.

Les documents officiels doivent provenir d’un instantané immuable des données utilisées à leur génération. Une modification ultérieure ne réécrit pas silencieusement un PDF déjà émis.

## Conception technique proposée

- Définir un modèle de données commun `DocumentAcademique` : type, portée (étudiant/classe/UE/cohorte/requête), période, version, état, référence, instantané JSON, chemin de stockage, empreinte SHA-256, générateur, date, approbateurs et publication liée.
- Conserver `proces_verbal_note` pour les PV transmis/retournés par le circuit de notes ; ne pas mélanger leur dépôt avec les bulletins ou PVR de jury.
- Centraliser le contexte de génération et les règles de composition. Un même modèle PDF doit être utilisé par les parcours enseignant, agent et étudiant afin d’éviter les variantes de calcul et de présentation.
- Prévoir des exports PDF imprimables et un écran d’aperçu avant émission. Les versions officielles portent un identifiant vérifiable et leur état ; les brouillons portent un filigrane « PROVISOIRE ».
- Produire les exports de cohorte uniquement aux agents/jurys autorisés ; limiter le téléchargement étudiant à ses propres documents.

## Étapes de réalisation

1. Valider les champs/mentions institutionnels et les rôles signataires auprès de la Faculté.
2. Stabiliser les maquettes : PV par évaluation, PV SN, PV de rattrapage, PVR récapitulatif, PVR de requêtes et bulletin individuel.
3. Ajouter la persistance versionnée des documents et les références d’audit.
4. Construire les services de composition des données et génération PDF à partir des instantanés officiels.
5. Relier les actions UI : aperçu, transmettre, contrôler, retourner, publier, générer et télécharger selon les rôles.
6. Vérifier visuellement les PDFs par comparaison avec les scans fournis, puis vérifier les cas métier : note EL, absence, composante non prévue, rattrapage, requête acceptée/rejetée, publication et nouvelle version.

## Points à confirmer avant émission officielle

- Libellés institutionnels exacts et logos à utiliser par faculté/département.
- Titres officiels de CC, TP/TPE, SN et rattrapage ; le fichier CC fourni mentionne « EP » dans son titre intérieur.
- Signataires obligatoires et ordre des visas selon le document (enseignant, cellule, chef de département, président du jury, scolarité).
- Barème officiel pour chaque profil et correspondance des mentions/décisions, notamment codes CA, CANT, NC, EL, ADM/ECHEC.
- Si les PV de requêtes doivent inclure uniquement les dossiers décidés ou également les dossiers en attente/ajournés.
- Si les bulletins doivent être semestriels, annuels, ou les deux ; le modèle fourni est un relevé annuel individuel.
