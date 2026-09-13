# GNU Base PostgreSQL

Version initiale 1.0, fondée sur le cahier des spécifications 1.2 et la proposition relationnelle à 29 tables. Le fichier `001_creation.sql` contient toute la création : schéma `gnu`, domaines numériques, tables, clés étrangères, index, fonctions de calcul, vues et triggers. Aucun backend ni écran Flutter n’est inclus.

## Installation

Prérequis : PostgreSQL 14 ou supérieur, client `psql`, Bash. Le compte d’installation doit pouvoir créer le schéma dans la base cible; l’option `--create-db` exige également le droit de créer une base. Aucun paquet n’est installé automatiquement.

Après extraction de l’archive, ouvrir un terminal dans son dossier `GNU_PostgreSQL` :

```bash
export PGHOST=localhost
export PGPORT=5432
export PGUSER=postgres
export PGDATABASE=gnu_notes
bash installer.sh --create-db --tests
```

Adapter le port à ton instance PostgreSQL. Si la base existe déjà et ne contient pas le schéma `gnu`, utiliser simplement :

```bash
bash installer.sh --tests
```

Le script utilise l’authentification PostgreSQL habituelle, par invite ou fichier `.pgpass` correctement protégé. Il n’embarque aucun mot de passe. Ne pas mettre un mot de passe dans le fichier SQL ou dans un dépôt Git.

Le SQL peut aussi être exécuté directement, dans une base existante :

```bash
psql -X -v ON_ERROR_STOP=1 -f 001_creation.sql
```

L’installation est une transaction : une erreur annule la création du schéma. Une seconde exécution refuse le schéma existant; elle ne fait ni DROP DATABASE, ni DROP SCHEMA, ni TRUNCATE. Une base nouvellement créée par `createdb` reste présente mais vide si l’installation SQL échoue. Ce fichier est une migration initiale, pas un outil de mise à niveau d’une base déjà utilisée.

## Fichiers

| Fichier | Rôle |
|---|---|
| `001_creation.sql` | Création complète et fonctions métier |
| `002_tests.sql` | Recette sur schéma vide, données fictives annulées |
| `003_droits.sql` | Droits d’un rôle Laravel existant, distinct du propriétaire |
| `installer.sh` | Création optionnelle de la base puis installation |
| `tester.sh` | Exécution ultérieure des tests sur une base de test vide |
| `VERIFICATION.md` | Résultats de vérification et limites |
| `SHA256SUMS` | Empreintes des fichiers |

Les 29 tables métier sont : universite, faculte, departement, filiere, niveau, annee_academique, classe, ue, matiere, utilisateur, etudiant, enseignant, inscription_classe, inscription_ue, affectation, evaluation, plan_evaluation, ligne_plan, note, historique_note, requete, justificatif, decision_requete, session_rattrapage, candidature_rattrapage, publication, bulletin, notification, journal_audit. Les tables techniques de Laravel pourront s’ajouter séparément.

## Compte serveur Laravel

Le compte d’installation reste propriétaire des objets. Le compte Laravel doit être un rôle distinct et sans privilèges de superutilisateur ni d’administration. Créer ce rôle selon les pratiques de ton serveur, puis lui attribuer les droits fournis :

```bash
psql -X -v ON_ERROR_STOP=1 -v app_role=gnu_app -f 003_droits.sql
```

Ou définir `GNU_APP_ROLE=gnu_app` avant l’installation. Ce rôle doit déjà exister. Le fichier ne crée aucun compte ni mot de passe et ne change pas les méthodes d’authentification du serveur.

Le rôle applicatif a accès aux données de l’application. Il est réservé au backend de confiance : les étudiants et enseignants ne reçoivent jamais ses identifiants. Laravel doit contrôler chaque rôle, propriétaire et affectation avant de lancer le SQL. Les paramètres de contexte ci-dessous ne sont pas une authentification PostgreSQL des personnes; c’est Laravel qui doit les dériver de l’utilisateur réellement connecté, jamais d’un identifiant arbitraire fourni par le client.

La publication directe et l’écriture directe de l’historique ou du journal sont retirées au rôle applicatif. Les triggers produisent ces historiques, et la fonction `gnu.publier_classe` réalise la publication officielle. Aucun DELETE n’est accordé au rôle applicatif; les objets utilisés sont archivés.

## Contexte des écritures

Chaque transaction de saisie doit fournir l’utilisateur connecté et un motif. Les identifiants ci-dessous sont des exemples à remplacer par ceux de la base réelle :

```sql
BEGIN;
SELECT set_config('gnu.acteur_id', '12', true);
SELECT set_config('gnu.motif', 'Correction de transcription', true);
SELECT set_config('gnu.origine', 'CORRECTION', true);

UPDATE gnu.note
SET valeur_note = 62, statut_note = 'VALIDEE', version_note = 3
WHERE id = 42 AND version_note = 3;
-- Vérifier qu’exactement une ligne a été modifiée; sinon conflit à traiter.
COMMIT;
```

`version_note` transmis est la version lue. Le trigger l’incrémente et refuse une valeur obsolète. La clause WHERE version protège aussi l’appel applicatif; vérifier le nombre de lignes modifiées. Toute correction reste attribuée à un enseignant responsable actif. Pour une décision de jury, ajouter `gnu.origine=JURY`, `gnu.reference_jury` et un motif. `gnu.decision_id` peut conserver la décision de requête associée. Les paramètres `set_config(..., true)` sont locaux à la transaction; ne pas les laisser persistants dans un pool de connexions.

Les états NUMERIQUE, ABSENTE et MANQUANTE sont distincts. Une note ABSENTE au rattrapage, définitivement validée, consomme la tentative et produit EL. Une absence en session normale reste à résoudre et empêche le calcul officiel concerné; elle ne devient pas automatiquement zéro. Pour une modification d’une note validée à recontrôler, choisir BROUILLON : les champs de validation sont remis à NULL, les anciennes versions restent intactes.

## Préparation du catalogue et des plans

Créer une UE avec `statut_catalogue=BROUILLON`, puis ses un ou deux EC, puis activer l’UE. Une UE activée et ses EC sont immuables sur leurs valeurs pédagogiques : créer une nouvelle version de programme pour une modification. `Code_UE` est unique à l’intérieur du niveau et de la version. Le code d’EC est également contrôlé dans le niveau et la version.

Un seul enseignant responsable actif est prévu par EC et classe. Créer un plan BROUILLON, ajouter les lignes normales CC/TP/SN, puis activer le plan. Les lignes retenues doivent totaliser exactement 100 %. Les lignes actives ne se modifient pas; archiver l’ancien plan et activer une nouvelle version dans une transaction. Un plan individuel exige la décision approuvée correspondante et le plan commun parent.

Le SQL ne fixe aucun pourcentage global : les 30/20/50 des tests sont seulement des données fictives. Une note de rattrapage n’est pas une seconde ligne du plan; elle remplace la source de sa composante, au même poids.

## Calcul et publication

Fonctions disponibles :

```sql
SELECT gnu.calculer_ec(1, 1);             -- inscription UE, matière
SELECT gnu.calculer_ue(1);                -- inscription UE
SELECT gnu.calculer_bulletin(1, 'ANNUELLE'); -- inscription de classe
SELECT * FROM gnu.liste_rattrapage_sn;
SELECT * FROM gnu.effectifs_classes;
```

Elles produisent le détail JSON des sources, poids, versions, arrondis et grades. Les EC sont arrondis au plafond, puis l’UE est calculée avec ces EC arrondis et arrondie à son tour. La MGP utilise les crédits UE. Pour l’admission, le numérateur exact doit atteindre deux fois le dénominateur, toutes les UE doivent être à au moins 35 et aucune ne doit porter EL. La MGP n’est pas arrondie au plafond.

La publication d’une classe utilise une transaction à instantané cohérent :

```sql
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT set_config('gnu.acteur_id', '15', true); -- compte d’un agent actif
SELECT set_config('gnu.motif', 'Publication annuelle validée', true);
SELECT gnu.publier_classe(1, 'ANNUELLE');
COMMIT;
```

Périodes autorisées : S1, S2, ANNUELLE. La fonction refuse le niveau d’isolation READ COMMITTED. Elle verrouille les publications de la classe et les notes existantes, recalcule les bulletins et conserve les anciennes versions. Laravel doit prévoir une relance bornée de la transaction en cas d’erreur de sérialisation ou d’interblocage, sans dupliquer les opérations déjà validées.

Les bulletins incluent les UE fondamentales du parcours et les UE optionnelles inscrites. Les inscriptions obligatoires manquantes ou notes non validées bloquent la publication. Une UE EL garde la mention EL avec note officielle NULL, contribue 0 point et garde ses crédits au dénominateur; le résultat annuel est ECHEC.

## Requêtes, reprise et rattrapage

Une requête référence le bulletin contesté. Le serveur fixe sa date réelle de soumission et vérifie 48 heures consécutives. Une republication ne renouvelle le délai que si la note ciblée, ou l’EC ciblé pour une requête sans note, a changé. Une requête d’absence et ses justificatifs sont insérés ensemble dans une transaction; le contrôle de présence des pièces est différé jusqu’au COMMIT.

Les fichiers justificatifs eux-mêmes restent dans un stockage privé. La base conserve leurs références, tailles et empreintes; Laravel doit contrôler les octets, formats, existence et téléchargements. Les triggers ne peuvent pas vérifier le contenu d’un fichier externe.

La vue `liste_rattrapage_sn` est disponible dès publication. Pour organiser une épreuve, créer son évaluation de mode RATTRAPAGE et une candidature correspondante; la session peut être renseignée plus tard. La portée unique est étudiant, année, niveau et code d’EC. Les champs de portée sont dérivés par trigger; aucune seconde ligne ni remise à zéro d’une tentative consommée n’est permise. La validation de la note NUMERIQUE ou ABSENTE consomme cette candidature automatiquement.

Lors d’une reprise annuelle, créer des inscriptions UE de type CONSERVEE pour les UE ≥ 50 sans EL et de type REPRISE pour les autres. Fournir le bulletin et l’UE sources de l’année antérieure. Tous les EC d’une UE reprise attendent de nouvelles notes. Une UE conservée référence ses anciens résultats et ne peut recevoir de nouvelles notes.

L’égalité du code UE et du niveau sert à reconnaître une UE entre versions. Une équivalence pédagogique entre codes différents n’est pas automatisée : elle nécessite une décision et une extension explicites.

## Rappels ouvrables

La fonction suivante crée des notifications internes en attente; elle n’envoie aucun e-mail ni SMS :

```sql
SELECT gnu.rappeler_notes(
  'CAL-2026', 'Africa/Douala',
  ARRAY['2026-12-25'::date]
);
```

La liste de fermetures ci-dessus est un exemple, pas un calendrier officiel. Fournir la liste complète validée de jours fériés et fermetures de l’établissement. La version doit correspondre à celle de l’évaluation. Appeler la fonction depuis le planificateur Laravel à l’heure choisie chaque jour ouvrable. Elle compte à partir du lendemain de l’évaluation, crée le premier rappel après deux jours ouvrables, puis un par jour ouvrable jusqu’à saisie ET validation complètes. Une clé unique empêche les doublons pour le même destinataire, l’évaluation et le jour. Les UE conservées sont exclues.

Les versions complètes du calendrier doivent être archivées par le déploiement; les notifications gardent aussi les paramètres utilisés. La fonction ne crée pas automatiquement une tâche planifiée et ne choisit pas l’heure à la place de l’établissement.

## Vérification avant usage

```bash
bash tester.sh
```

Les tests refusent une base contenant déjà des utilisateurs. Ils créent des données fictives et un rôle de test dans une transaction puis les annulent. Les séquences PostgreSQL ne sont pas transactionnelles : leurs compteurs peuvent avancer, ce qui est normal. Utiliser une base exclusivement destinée aux tests. Le compte de test doit pouvoir créer un rôle temporairement dans sa transaction; sinon exécuter cette recette avec un administrateur de la base de test.

Cette livraison fournit un schéma et des calculs exécutables, pas une application prête à déployer. Restent l’API Laravel, les écrans Flutter, l’authentification des personnes, le stockage des pièces, la configuration d’exploitation et les essais sur un serveur PostgreSQL natif avec plusieurs connexions.

Références techniques : [contraintes PostgreSQL](https://www.postgresql.org/docs/current/ddl-constraints.html), [triggers PostgreSQL](https://www.postgresql.org/docs/current/sql-createtrigger.html), [fonctions PostgreSQL](https://www.postgresql.org/docs/current/sql-createfunction.html).
