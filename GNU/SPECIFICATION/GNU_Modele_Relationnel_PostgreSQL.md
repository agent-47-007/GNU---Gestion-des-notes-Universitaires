

# GNU Proposition de modèle relationnel PostgreSQL

Version de travail 1.0 • Fondée sur le cahier de spécifications 1.2 • 09 septembre 2026

Cette revue traduit les 29 entités existantes en 29 tables métier proposées. Aucune nouvelle table utilisateur n’a été transmise dans ce tour : il s’agit de la revue de notre modèle, pas d’une validation de tables reproduites par le porteur du projet. Aucun SQL ni migration n’a été exécuté. Les tables techniques éventuelles de Laravel (sessions, files de tâches, migrations) ne sont pas comprises dans ce total.

## Conventions de lecture

Chaque table reçoit une clé primaire technique `id bigint GENERATED ALWAYS AS IDENTITY`. Ce choix de réalisation remplace les PK métier du diagramme sans supprimer les codes du recueil : Code_UE, Code_M, EID et Matricule restent des clés métier avec les unicités précisées. Les identifiants relationnels sont stables et ne changent pas lorsqu’un libellé ou code corrigeable change. Les autres Code_* purement techniques sont représentés par `id`, sans créer un second code textuel inutile.

Les noms SQL utilisent minuscules et underscores, sans accents; les interfaces conservent les libellés français. `→ table` désigne une FK vers `table.id`; `?` signifie nullable, tous les autres champs sont NOT NULL. PK signifie clé primaire; FK clé étrangère; UNIQUE interdit les doublons sur la combinaison complète; CHECK contrôle une ligne. Ajouter `created_at timestamptz` aux tables mutables et `updated_at timestamptz` à celles dont les valeurs courantes changent; les dates événementielles restent distinctes.

Les valeurs décimales utilisent `numeric` sans arrondi implicite de colonne. Les entrées non finies (NaN, infinis) sont refusées explicitement, y compris pour crédits, poids et MGP. L’application limite la longueur des saisies et conserve les décimales acceptées. Le calcul du plafond est explicite, uniquement pour EC et UE. Les états textuels reçoivent des CHECK nommés, sans tables de référence supplémentaires. Textes métier obligatoires : non vides après suppression des espaces périphériques.

Les données JSON sont réservées aux instantanés de bulletin, aux historiques complets et aux messages techniques; elles ne remplacent pas les FK des inscriptions, notes ou requêtes.

## Corrections issues de la revue

| Problème | Correction proposée |
|---|---|
| Code_UE seul ne distingue pas les versions d’un programme | id technique et UNIQUE(niveau, version, code_ue) |
| Requête sans référence à sa publication | bulletin_conteste_id, d’où la publication et son heure |
| UE conservée sans résultat source | type CONSERVEE, bulletin_source_id et ue_source_id |
| Éligibilité et tentative confondues | Candidature persistante, portée unique et date de consommation |
| Liste indisponible tant qu’une session n’est pas créée | session_id nullable pendant l’éligibilité |
| Deux références à la même publication dans une candidature | Publication déduite du bulletin source |
| EL confondu avec note zéro | Statut EL dans le résultat figé, 0 point pour MGP, crédits conservés |
| Deux enseignants pourraient activer des plans concurrents | Un responsable actif par EC et classe, proposition explicite |

## Dictionnaire des 29 tables


### 01 universite

Notation d’origine : **Code_Univ**. PK : `id`.

| Champ | Type et référence | Nullable |
|---|---|---|
| `code_univ` | text | Non |
| `nom_univ` | text | Non |



**Contraintes et comportement.** UNIQUE(code_univ).



### 02 faculte

Notation d’origine : **Code_Fac**. PK : `id`.

| Champ | Type et référence | Nullable |
|---|---|---|
| `code_fac` | text | Non |
| `nom_fac` | text | Non |
| `universite_id` | bigint → universite | Non |



**Contraintes et comportement.** UNIQUE(universite_id, code_fac).



### 03 departement

Notation d’origine : **Code_De**. PK : `id`.

| Champ | Type et référence | Nullable |
|---|---|---|
| `code_de` | text | Non |
| `nom_depart` | text | Non |
| `faculte_id` | bigint → faculte | Non |



**Contraintes et comportement.** UNIQUE(faculte_id, code_de).



### 04 filiere

Notation d’origine : **Code_F**. PK : `id`.

| Champ | Type et référence | Nullable |
|---|---|---|
| `code_f` | text | Non |
| `nom_f` | text | Non |
| `departement_id` | bigint → departement | Non |



**Contraintes et comportement.** UNIQUE(departement_id, code_f).



### 05 niveau

Notation d’origine : **Code_Niv**. PK : `id`.

| Champ | Type et référence | Nullable |
|---|---|---|
| `code_niv` | text | Non |
| `cycle_niv` | text | Non |
| `libelle_niv` | text | Non |
| `filiere_id` | bigint → filiere | Non |



**Contraintes et comportement.** UNIQUE(filiere_id, code_niv).



### 06 annee_academique

Notation d’origine : **Annee_Academique**. PK : `id`.

| Champ | Type et référence | Nullable |
|---|---|---|
| `libelle` | text | Non |
| `date_debut` | date | Non |
| `date_fin` | date | Non |



**Contraintes et comportement.** UNIQUE(libelle); CHECK(date_fin > date_debut).



### 07 classe

Notation d’origine : **Code_Classe**. PK : `id`.

| Champ | Type et référence | Nullable |
|---|---|---|
| `code_classe` | text | Non |
| `niveau_id` | bigint → niveau | Non |
| `annee_id` | bigint → annee_academique | Non |
| `version_programme` | integer | Non |



**Contraintes et comportement.** UNIQUE(code_classe); UNIQUE(niveau_id, annee_id); version_programme > 0. Une classe représente tout le niveau pour cette année; aucun groupe supplémentaire implicite. Effectif dérivé des inscriptions validées.



### 08 ue

Notation d’origine : **Code_UE**. PK : `id`.

| Champ | Type et référence | Nullable |
|---|---|---|
| `code_ue` | text | Non |
| `intitule_ue` | text | Non |
| `niveau_id` | bigint → niveau | Non |
| `version_programme` | integer | Non |
| `numero_semestre` | smallint | Non |
| `categorie_ue` | text | Non |
| `credit_ue` | numeric | Non |
| `statut_catalogue` | text | Non |



**Contraintes et comportement.** UNIQUE(niveau_id, version_programme, code_ue). Version > 0, semestre IN (1,2), catégorie IN (FONDAMENTALE, OPTIONNELLE), crédits strictement positifs et finis, statut IN (BROUILLON, ACTIF, ARCHIVE). Une version active possède 1 à 2 EC. Une version utilisée est immuable; créer une nouvelle ligne lors du changement de programme.



### 09 matiere

Notation d’origine : **Code_M**. PK : `id`.

| Champ | Type et référence | Nullable |
|---|---|---|
| `code_m` | text | Non |
| `intitule_matiere` | text | Non |
| `ue_id` | bigint → ue | Non |
| `rang_ec` | smallint | Non |
| `credit_matiere` | numeric | Non |



**Contraintes et comportement.** UNIQUE(ue_id, code_m); UNIQUE(ue_id, rang_ec); rang IN (1,2), crédits positifs et finis. Rang + unicité limitent à deux EC; le minimum un est contrôlé à l’activation de l’UE. Un seul intitulé, sans doublon Libellé/Intitulé. Code_M doit garder la même identité métier entre versions; une correspondance de programme non évidente nécessite une décision explicite.



### 10 utilisateur

Notation d’origine : **Code_Utilisateur**. PK : `id`.

| Champ | Type et référence | Nullable |
|---|---|---|
| `code_utilisateur` | text | Non |
| `login` | text | Non |
| `mot_de_passe_hash` | text | Non |
| `role` | text | Non |
| `actif` | boolean | Non |
| `nom` | text | Non |
| `prenom` | text | Oui |



**Contraintes et comportement.** UNIQUE(code_utilisateur); index UNIQUE(lower(login)); login non vide; rôle IN (ETUDIANT, ENSEIGNANT, AGENT). Aucun mot de passe en clair. Un seul rôle par compte dans ce périmètre.



### 11 etudiant

Notation d’origine : **Matricule**. PK : `id`.

| Champ | Type et référence | Nullable |
|---|---|---|
| `matricule` | text | Non |
| `utilisateur_id` | bigint → utilisateur | Non |



**Contraintes et comportement.** UNIQUE(matricule); UNIQUE(utilisateur_id). Profil compatible avec rôle ETUDIANT. Compte 1 → étudiant 0..1; étudiant → compte exactement 1.



### 12 enseignant

Notation d’origine : **EID**. PK : `id`.

| Champ | Type et référence | Nullable |
|---|---|---|
| `eid` | text | Non |
| `utilisateur_id` | bigint → utilisateur | Non |
| `fonction_enseignant` | text | Oui |



**Contraintes et comportement.** UNIQUE(eid); UNIQUE(utilisateur_id). Profil compatible ENSEIGNANT. L’agent est un rôle de utilisateur, sans table agent.



### 13 inscription_classe

Notation d’origine : **Code_Inscription_Classe**. PK : `id`.

| Champ | Type et référence | Nullable |
|---|---|---|
| `etudiant_id` | bigint → etudiant | Non |
| `classe_id` | bigint → classe | Non |
| `statut_redoublant` | boolean | Non |
| `statut_inscription` | text | Non |



**Contraintes et comportement.** UNIQUE(etudiant_id, classe_id). Statut IN (BROUILLON, VALIDEE, ANNULEE). Une annulation change le statut de la ligne existante; une réactivation ne crée pas un doublon.



### 14 inscription_ue

Notation d’origine : **Code_Inscription_UE**. PK : `id`.

| Champ | Type et référence | Nullable |
|---|---|---|
| `inscription_classe_id` | bigint → inscription_classe | Non |
| `ue_id` | bigint → ue | Non |
| `type_inscription` | text | Non |
| `statut_inscription` | text | Non |
| `bulletin_source_id` | bigint  → bulletin | Oui |
| `ue_source_id` | bigint  → ue | Oui |



**Contraintes et comportement.** UNIQUE(inscription_classe_id, ue_id). Type IN (NORMALE, REPRISE, CONSERVEE); statut IN (BROUILLON, VALIDEE, ANNULEE). CONSERVEE exige les deux références source; NORMALE les interdit; REPRISE les exige pour justifier la reprise. Source du même étudiant, année antérieure; UE source présente dans le bulletin figé. UE conservée ≥ 50 sans EL. UE reprise < 50 ou EL : tous ses EC sont réévalués. Les changements de programme ne sont pas assimilés automatiquement.



### 15 affectation

Notation d’origine : **Code_Affectation**. PK : `id`.

| Champ | Type et référence | Nullable |
|---|---|---|
| `enseignant_id` | bigint → enseignant | Non |
| `matiere_id` | bigint → matiere | Non |
| `classe_id` | bigint → classe | Non |
| `actif` | boolean | Non |



**Contraintes et comportement.** Index UNIQUE(matiere_id, classe_id) WHERE actif. Proposition : un enseignant responsable actif par EC et classe, pour éviter deux plans communs concurrents. Réaffecter en archivant l’ancienne affectation, sans effacer ses notes. La co-intervention n’est pas modélisée dans cette version. Cohérence niveau et version de programme obligatoire.



### 16 evaluation

Notation d’origine : **Code_Evaluation**. PK : `id`.

| Champ | Type et référence | Nullable |
|---|---|---|
| `affectation_id` | bigint → affectation | Non |
| `type_eval` | text | Non |
| `date_evaluation` | timestamptz | Non |
| `mode_evaluation` | text | Non |
| `statut_evaluation` | text | Non |
| `evaluation_origine_id` | bigint  → evaluation | Oui |
| `version_calendrier` | text | Non |



**Contraintes et comportement.** Type IN (CC,TP,SN), mode IN (NORMALE,RATTRAPAGE), statut IN (BROUILLON,PROGRAMMEE,REALISEE,ANNULEE). Mode normal : origine nulle; rattrapage : origine requise et différente de id. Origine normale, même EC, classe et type. Aucun cycle de remplacements. Une annulation ne consomme pas une nouvelle tentative; une absence à une épreuve tenue la consomme.



### 17 plan_evaluation

Notation d’origine : **Code_Plan**. PK : `id`.

| Champ | Type et référence | Nullable |
|---|---|---|
| `affectation_id` | bigint → affectation | Non |
| `version_plan` | integer | Non |
| `statut_plan` | text | Non |
| `portee` | text | Non |
| `inscription_ue_id` | bigint  → inscription_ue | Oui |
| `decision_id` | bigint  → decision_requete | Oui |
| `plan_commun_id` | bigint  → plan_evaluation | Oui |



**Contraintes et comportement.** Version > 0; statut IN (BROUILLON,ACTIF,ARCHIVE); portée IN (CLASSE,ETUDIANT). CLASSE : trois références optionnelles nulles. ETUDIANT : toutes requises. Parent de portée CLASSE et même affectation, sans cycle. Décision approuvée pour le même étudiant et EC. Unicités partielles : (affectation_id,version_plan) pour CLASSE; (affectation_id,inscription_ue_id,version_plan) pour ETUDIANT; une version ACTIVE par même périmètre. Plans publiés immuables; nouvelle version pour tout changement.



### 18 ligne_plan

Notation d’origine : **Code_Ligne_Plan**. PK : `id`.

| Champ | Type et référence | Nullable |
|---|---|---|
| `plan_id` | bigint → plan_evaluation | Non |
| `evaluation_id` | bigint → evaluation | Non |
| `retenue` | boolean | Non |
| `poids_evaluation` | numeric | Non |



**Contraintes et comportement.** UNIQUE(plan_id,evaluation_id). Poids fini dans [0,100]. Proposition : retenue implique poids > 0; non retenue implique poids = 0. Somme des poids retenus = 100 à l’activation. Évaluation normale du même EC et de la même classe. Un rattrapage remplace la source effective de cette ligne, sans ajouter une seconde contribution.



### 19 note

Notation d’origine : **Code_Note**. PK : `id`.

| Champ | Type et référence | Nullable |
|---|---|---|
| `evaluation_id` | bigint → evaluation | Non |
| `inscription_ue_id` | bigint → inscription_ue | Non |
| `valeur_note` | numeric | Oui |
| `situation` | text | Non |
| `statut_note` | text | Non |
| `version_note` | integer | Non |
| `validateur_id` | bigint  → enseignant | Oui |
| `date_validation` | timestamptz | Oui |



**Contraintes et comportement.** UNIQUE(evaluation_id,inscription_ue_id). Situation IN (NUMERIQUE,ABSENTE,MANQUANTE); statut IN (BROUILLON,VALIDEE); version > 0. NUMERIQUE impose valeur finie de 0 à 100; les autres imposent NULL. VALIDEE impose validateur et date; BROUILLON les laisse NULL. Une donnée MANQUANTE n’est pas validable pour publication. EL est dérivé de l’absence au rattrapage puis conservé dans le bulletin; ce n’est pas une valeur numérique. Une note exige un EC de l’UE inscrite et la même classe, hors UE conservée.



### 20 historique_note

Notation d’origine : **Code_Historique_Note**. PK : `id`.

| Champ | Type et référence | Nullable |
|---|---|---|
| `note_id` | bigint → note | Non |
| `version_note` | integer | Non |
| `auteur_id` | bigint → utilisateur | Non |
| `date_modification` | timestamptz | Non |
| `motif` | text | Non |
| `origine_modification` | text | Non |
| `decision_id` | bigint  → decision_requete | Oui |
| `reference_jury` | text | Oui |
| `avant` | jsonb | Oui |
| `apres` | jsonb | Non |



**Contraintes et comportement.** UNIQUE(note_id,version_note); version > 0; motif non vide. Origine IN (SAISIE,CORRECTION,RATTRAPAGE,REQUETE,JURY,VALIDATION). Première saisie : avant NULL; suivantes : avant et après complets, incluant situation, valeur et validation. JURY impose reference_jury non vide. Ajouter une entrée à chaque modification; ne jamais modifier/supprimer une entrée. Auteur enseignant pour saisie et validation; journal technique complémentaire séparé.



### 21 requete

Notation d’origine : **Code_Re**. PK : `id`.

| Champ | Type et référence | Nullable |
|---|---|---|
| `inscription_ue_id` | bigint → inscription_ue | Non |
| `matiere_id` | bigint → matiere | Non |
| `evaluation_id` | bigint  → evaluation | Oui |
| `note_id` | bigint  → note | Oui |
| `bulletin_conteste_id` | bigint → bulletin | Non |
| `objet` | text | Non |
| `description` | text | Non |
| `type_requete` | text | Non |
| `statut_requete` | text | Non |
| `date_soumission` | timestamptz | Non |



**Contraintes et comportement.** Type IN (ABSENCE,CONTESTATION,NOTE_MANQUANTE,REEVALUATION); statut IN (SOUMISE,EN_TRAITEMENT,DECIDEE). Bulletin du même étudiant et de la même année; EC, évaluation et note éventuelles cohérents. Fenêtre : publication contestée ≤ soumission ≤ publication + 48 h, heure serveur. Pour une republication, prouver que la note ciblée a changé par rapport à la version précédente : une correction d’autrui ne rouvre pas ce délai. Justificatif obligatoire pour ABSENCE.



### 22 justificatif

Notation d’origine : **Code_Justificatif**. PK : `id`.

| Champ | Type et référence | Nullable |
|---|---|---|
| `requete_id` | bigint → requete | Non |
| `reference_fichier_prive` | text | Non |
| `type_fichier` | text | Non |
| `taille_octets` | bigint | Non |
| `empreinte` | text | Non |
| `date_depot` | timestamptz | Non |



**Contraintes et comportement.** Taille > 0; référence privée non vide. Plusieurs pièces possibles. L’objet stocké doit exister avant soumission; contrôle de type et accès côté serveur. Aucune URL publique dans le bulletin. Suppression d’une preuve requise après soumission interdite hors procédure de rétention définie.



### 23 decision_requete

Notation d’origine : **Code_Decision**. PK : `id`.

| Champ | Type et référence | Nullable |
|---|---|---|
| `requete_id` | bigint → requete | Non |
| `enseignant_id` | bigint → enseignant | Non |
| `version_decision` | integer | Non |
| `action_decision` | text | Non |
| `motif` | text | Non |
| `date_decision` | timestamptz | Non |
| `courante` | boolean | Non |



**Contraintes et comportement.** UNIQUE(requete_id,version_decision), version > 0; index UNIQUE(requete_id) WHERE courante. Action IN (AUTORISER_EVALUATION,ATTRIBUER_ZERO,CORRIGER_NOTE,REJETER). Motif non vide. Enseignant habilité sur l’EC. Versions anciennes immuables; seules les métadonnées courante peuvent changer transactionnellement. Une autorisation ne contourne jamais la tentative unique.



### 24 session_rattrapage

Notation d’origine : **Code_Session**. PK : `id`.

| Champ | Type et référence | Nullable |
|---|---|---|
| `classe_id` | bigint → classe | Non |
| `libelle` | text | Non |
| `date_session` | date | Non |
| `statut_session` | text | Non |



**Contraintes et comportement.** Statut IN (PREVUE,OUVERTE,CLOTUREE,ANNULEE). Plusieurs sessions organisationnelles possibles pour la classe, mais une seule tentative effective par EC et étudiant. Date de chaque épreuve dans evaluation.



### 25 candidature_rattrapage

Notation d’origine : **Code_Candidature**. PK : `id`.

| Champ | Type et référence | Nullable |
|---|---|---|
| `session_id` | bigint  → session_rattrapage | Oui |
| `inscription_ue_id` | bigint → inscription_ue | Non |
| `matiere_id` | bigint → matiere | Non |
| `etudiant_id` | bigint → etudiant | Non |
| `annee_id` | bigint → annee_academique | Non |
| `niveau_id` | bigint → niveau | Non |
| `code_m_scope` | text | Non |
| `bulletin_source_id` | bigint → bulletin | Non |
| `evaluation_origine_id` | bigint → evaluation | Non |
| `evaluation_rattrapage_id` | bigint  → evaluation | Oui |
| `autorisation_id` | bigint  → decision_requete | Oui |
| `statut_candidature` | text | Non |
| `date_consommation` | timestamptz | Oui |



**Contraintes et comportement.** UNIQUE(etudiant_id,annee_id,niveau_id,code_m_scope). Les quatre champs de portée sont dérivés des références et vérifiés par trigger, non fournis librement par le client. Une seule ligne par portée, même après republication ou réinscription. Statut IN (ELIGIBLE,AUTORISEE,PROGRAMMEE,COMPOSEE,ABSENTE,ANNULEE). COMPOSEE ou ABSENTE exige date_consommation et évaluation de rattrapage; après consommation, aucune nouvelle tentative. Une correction de saisie ne remet pas la consommation à NULL. Origine SN : EC arrondi < 50 dans la source. Origine CC/TP : autorisation obligatoire. Session peut être NULL avant organisation : la liste reste disponible dès publication. Suppression de publication_source_id redondant, déduit du bulletin.



### 26 publication

Notation d’origine : **Code_Publication**. PK : `id`.

| Champ | Type et référence | Nullable |
|---|---|---|
| `classe_id` | bigint → classe | Non |
| `periode` | text | Non |
| `version_publication` | integer | Non |
| `date_publication` | timestamptz | Non |
| `agent_publicateur_id` | bigint → utilisateur | Non |
| `publication_precedente_id` | bigint  → publication | Oui |



**Contraintes et comportement.** UNIQUE(classe_id,periode,version_publication), version > 0; période IN (S1,S2,ANNUELLE). Agent de rôle AGENT. Précédente de même classe et période, version plus petite. Ne stocker ici que les publications finalisées; aperçu calculé avant insertion. Publication et bulletins insérés dans une transaction, immuables ensuite.



### 27 bulletin

Notation d’origine : **Code_Bulletin**. PK : `id`.

| Champ | Type et référence | Nullable |
|---|---|---|
| `publication_id` | bigint → publication | Non |
| `inscription_classe_id` | bigint → inscription_classe | Non |
| `periode` | text | Non |
| `version_bulletin` | integer | Non |
| `courant` | boolean | Non |
| `mgp_s1` | numeric | Oui |
| `mgp_s2` | numeric | Oui |
| `mgp_total` | numeric | Oui |
| `somme_points_credits` | numeric | Non |
| `total_credits` | numeric | Non |
| `decision_admission` | text | Non |
| `contenu_fige` | jsonb | Non |
| `version_schema_contenu` | integer | Non |
| `version_regles` | text | Non |
| `version_bareme` | text | Non |



**Contraintes et comportement.** UNIQUE(publication_id,inscription_classe_id); UNIQUE(inscription_classe_id,periode,version_bulletin); index UNIQUE(inscription_classe_id,periode) WHERE courant. Période identique à publication; classe identique à inscription. Crédits positifs et finis; MGP renseignées finies entre 0 et 4. Décision IN (ADMIS,ECHEC,NON_APPLICABLE); admission annuelle seulement. Pour comparer MGP ≥ 2, utiliser somme_points_credits ≥ 2 × total_credits, sans arrondi de division. Contenu JSON contrôlé; grades EL conservés. Corps immuable; courant seule métadonnée modifiable lors d’une republication.



### 28 notification

Notation d’origine : **Code_Notification**. PK : `id`.

| Champ | Type et référence | Nullable |
|---|---|---|
| `destinataire_id` | bigint → utilisateur | Non |
| `evaluation_id` | bigint  → evaluation | Oui |
| `requete_id` | bigint  → requete | Oui |
| `type_notification` | text | Non |
| `cle_evenement` | text | Non |
| `contenu` | jsonb | Non |
| `jour_ouvrable` | date | Oui |
| `date_envoi` | timestamptz | Oui |
| `date_lecture` | timestamptz | Oui |
| `statut_envoi` | text | Non |



**Contraintes et comportement.** UNIQUE(destinataire_id,cle_evenement). Type IN (RAPPEL_NOTES,REQUETE_DEPOSEE,REQUETE_DECIDEE,PUBLICATION); statut IN (EN_ATTENTE,ENVOYEE,ECHEC). Rappel : évaluation et jour obligatoires; clé déterministe évaluation/jour, sans données privées. Jour calculé dans le fuseau du calendrier archivé; premier rappel J+2 ouvrables, puis quotidien ouvrable jusqu’à saisie ET validation complètes.



### 29 journal_audit

Notation d’origine : **Code_Audit**. PK : `id`.

| Champ | Type et référence | Nullable |
|---|---|---|
| `acteur_id` | bigint  → utilisateur | Oui |
| `origine` | text | Non |
| `action` | text | Non |
| `date_action` | timestamptz | Non |
| `type_objet` | text | Non |
| `identifiant_objet` | text | Non |
| `avant` | jsonb | Oui |
| `apres` | jsonb | Oui |
| `motif` | text | Non |



**Contraintes et comportement.** Origine IN (UTILISATEUR,SYSTEME). UTILISATEUR impose acteur, SYSTEME le laisse NULL. Ajouts seuls; pas de mots de passe, jetons ni contenu des pièces. La référence polymorphe type_objet/identifiant_objet ne constitue pas une FK PostgreSQL : validation applicative et conservation des objets référencés nécessaires.



## Contraintes qui nécessitent plusieurs lignes

Un CHECK simple ne garantit ni une somme de lignes ni une règle utilisant d’autres tables. PostgreSQL recommande les contraintes déclaratives appropriées pour ces liens; le contrôle complémentaire doit être conçu explicitement. Référence : [documentation PostgreSQL sur les contraintes](https://www.postgresql.org/docs/current/ddl-constraints.html).

| Règle | Protection prévue en base | Traitement Laravel |
|---|---|---|
| Maximum deux EC | rang_ec IN (1,2) + UNIQUE(ue_id,rang_ec) | Explication du refus |
| Au moins un EC actif | Trigger sur activation UE et modification/suppression des matières | Création catalogue en transaction |
| Somme des poids égale à 100 | Trigger d’activation, verrou du plan; refus de modifier ses lignes actives | Prévisualisation et version nouvelle |
| Classe, UE, EC, année cohérents | Triggers de cohérence sur écritures et interdiction de déplacer un parent utilisé | Contrôles de périmètre et erreurs explicites |
| Un seul rattrapage | Unicité de portée; trigger anti-réinitialisation après consommation | Réservation/verrou de candidature; transaction de note et consommation |
| Requête sous 48 h | Trigger de soumission basé sur publication immuable; pas de CHECK utilisant l’heure courante | Contrôle de fenêtre et indication d’échéance |
| Justificatif obligatoire | Trigger à la soumission, différé à la fin de transaction si pièces insérées ensemble | Contrôle existence objet privé et type de fichier |
| Historique exhaustif | Trigger d’historisation, motif/auteur obligatoires, refus UPDATE/DELETE historique | Auteur issu de la session authentifiée, motif saisi |
| Bulletin officiel stable | Refus UPDATE du corps et DELETE; exception bornée au drapeau courant | Calcul, validation JSON et publication atomique |
| Autorisations humaines | Droits SQL limités au service; pas d’accès direct étudiant à la BD | Contrôle rôle et affectation sur chaque requête, y compris pièces |

Les triggers sont ici spécifiés, pas encore écrits ou testés. Leurs contrôles doivent couvrir INSERT, UPDATE et DELETE ainsi que les changements de parent. Un simple contrôle préalable Laravel ne protège pas deux écritures concurrentes. Les verrous sont pris dans un ordre stable : inscription, candidature, plan, note puis publication selon le traitement; les transactions qui ne touchent qu’un sous-ensemble gardent cet ordre relatif. Le détail sera fixé dans les migrations et tests de concurrence.

## Relations et cardinalités à reproduire

Chaque FK obligatoire signifie qu’un enfant possède exactement un parent; chaque FK nullable signifie zéro ou un parent. Du parent vers l’enfant, la cardinalité est généralement 0..N, sauf profil étudiant/enseignant (0..1 par utilisateur grâce à UNIQUE), matières (1..2 lorsque UE active) et lignes de plan (1..N lorsque plan actif). Pendant la préparation, UE et plan peuvent avoir zéro enfant; l’activation vérifie le minimum.

Les bulletins sont nombreux par inscription annuelle, car les périodes et versions sont conservées. Une inscription UE appartient à exactement une inscription de classe et une UE versionnée. Une note appartient à exactement une évaluation et une inscription UE. Les profils optionnels évitent d’imposer un profil étudiant à un agent. Il n’existe donc pas de relation obligatoire 1–1 entre toutes les classes.

Les nouvelles FK vers bulletin depuis requete et inscription_ue doivent être ajoutées au prochain diagramme UML. Le compte de 53 associations de l’ancien diagramme ne décrit pas automatiquement cette proposition révisée.

## Bulletin figé et conservation des résultats

Le schéma de `contenu_fige` exige identité de l’étudiant, classe, année, période; codes et versions du catalogue; chaque UE avec crédits, chaque EC avec crédit, résultat brut et plafond; chaque évaluation contributrice avec identifiant/version de note et poids effectif; grade, points, EL éventuel; compteurs de crédits et sommes pondérées; copie intégrale des règles, barème et plan utilisés. La publication référence les versions exactes d’Historique note, pas seulement la valeur courante de Note.

Pour EL, `note_arrondie_ue` est NULL, `mention` vaut EL et `points_mgp` vaut 0. Les valeurs connues des EC restent conservées pour expliquer le dossier; elles ne remplacent pas EL par une moyenne numérique officielle. Les crédits de cette UE sont inclus dans total_credits. Toute présence EL impose ECHEC. Une UE sans EL reçoit son grade à partir de sa note entière.

La MGP affichée n’est pas un critère de décision arrondi. Conserver le numérateur et le dénominateur exacts; comparer le numérateur à deux fois le dénominateur. Pour les UE conservées, recopier le résultat source autorisé dans le nouveau bulletin avec provenance, sans exiger de nouvelles notes ni émettre de rappels à leur sujet.

Le JSON exige une validation de schéma et de références côté serveur; une FK ne vérifie pas une référence cachée dans du JSON. La duplication dans ce document figé est intentionnelle pour expliquer les anciens bulletins. Le schéma JSON détaillé et les requêtes statistiques restent à écrire avant réalisation.

## Suppressions et index

Politique proposée : FK ON DELETE RESTRICT, identifiants immuables; désactivation ou archivage des comptes, UE et affectations utilisés. Pas de suppression en cascade des notes, publications, preuves soumises ou résultats annuels. Le nettoyage d’un brouillon non utilisé doit supprimer ses enfants explicitement et dans une transaction. Les politiques de rétention ne sont pas décidées par cette proposition.

Les PK et UNIQUE créent leurs index; éviter de les dupliquer. Ajouter un index sur chaque FK qui n’est pas déjà en tête d’un index utile. Prévoir particulièrement : requete(statut_requete,date_soumission), evaluation(statut_evaluation,date_evaluation), notification(statut_envoi,date_envoi), historique_note(note_id,version_note), bulletin(inscription_classe_id,periode,courant). Le dernier historique possède déjà son UNIQUE : ne pas ajouter un index identique. Choisir les index JSON uniquement après définition des recherches réelles. Référence : [contraintes et index PostgreSQL](https://www.postgresql.org/docs/current/ddl-constraints.html).

`numeric` est choisi pour les calculs décimaux exacts et non pour une précision flottante approximative. Référence : [types numériques PostgreSQL](https://www.postgresql.org/docs/current/datatype-numeric.html).

## Scénarios de réception du schéma

1. Refuser une troisième matière; refuser l’activation d’une UE vide.
2. Accepter le même Code_UE dans une nouvelle version de programme; conserver l’ancien bulletin inchangé.
3. Refuser une note sur un EC extérieur à l’UE ou sur une inscription d’une autre classe.
4. Refuser 101, −1, NaN et infinis; distinguer valeur 0, absence et donnée manquante.
5. Refuser un plan à 90 % et deux plans actifs de même portée, y compris lors de deux transactions simultanées.
6. Accepter une requête avant son échéance; refuser juste après; une correction d’autrui ne renouvelle pas le délai.
7. Refuser une seconde tentative du même EC/étudiant/année, y compris après republication, absence ou nouvelle inscription.
8. Conserver UE ≥ 50; reprendre tous les EC des UE < 50 ou EL et conserver la provenance de l’année antérieure.
9. Vérifier le bulletin du cahier : MGP normale 2,40; après rattrapage 2,61; scénario EL 2,13 et ECHEC.
10. Corriger une note sur décision du jury : enseignant auteur/validateur, motif et référence jury; publication par agent; ancienne version préservée.
11. Arrêter les rappels seulement après saisie ET validation de toutes les notes attendues; exclure les UE conservées.
12. Refuser toute modification du corps d’un bulletin publié et toute suppression d’historique.

Ces scénarios ne sont pas encore exécutés sur PostgreSQL. La vérification réalisée dans ce livrable est une revue de couverture et des références de table; le bulletin arithmétique a été vérifié dans le cahier 1.2.

## Suite de la conception

Cette proposition peut maintenant être confrontée aux tables reproduites par le porteur du projet. Elle contient les clés, références, nullable, unicités et contrôles métier nécessaires. Avant exécution, convertir les contraintes en migrations, écrire les triggers et le schéma JSON, synchroniser le diagramme UML, puis exécuter les scénarios sur une base de test. La co-intervention, les équivalences entre programmes et les modalités de transfert restent hors des hypothèses validées; aucun comportement automatique n’est inventé pour ces cas.
