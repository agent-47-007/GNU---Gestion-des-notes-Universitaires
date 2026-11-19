# Importer les demandes de comptes

La commande `gnu:import-account-requests` importe un CSV d’étudiants ou
d’enseignants dans `gnu.demande_compte`. Elle ne crée pas de compte actif : les
demandes restent `EN_ATTENTE` jusqu’à la vérification et l’approbation par
l’administrateur système dans GNU.

## Préparer les données

Les fichiers de travail privés (ignorés par Git) sont dans
`backend/storage/app/imports/official_2025_2026/` :

- `comptes_etudiants_a_completer.csv` : matricule, nom, prénom, courriel,
  référence d’identité et nom complet tel qu’extrait de la liste INF342.
- `comptes_enseignants_a_completer.csv` : EID, nom, prénom, courriel,
  référence d’identité, nom de la répartition et alias source.
- `affectations_enseignants_l3_2025_2026_a_completer.csv` : codes de classe et
  EC, avec les EID à compléter après vérification de l’identité des enseignants.

Renseignez les colonnes `nom`, `prenom` et `reference_identite` des étudiants.
La référence doit correspondre à une pièce ou preuve vérifiée par l’université;
le matricule seul ne prouve pas l’identité. Pour chaque enseignant, confirmez le
nom complet, fournissez un EID officiel unique, puis renseignez nom, prénom et
référence vérifiée. Ne reprenez pas les noms candidats comme identité certaine.
Le script ne découpe pas automatiquement un nom complet et n’invente aucun EID.

Format CSV UTF-8, séparateur virgule. Les colonnes requises sont :

- étudiant : `matricule,nom,prenom,courriel,reference_identite`
- enseignant : `eid,nom,prenom,courriel,reference_identite`

Le courriel peut rester vide.

## Prévisualiser puis créer les demandes

Depuis `backend/`, choisissez le bon fichier et une base de recette avant la base
officielle. La première commande valide les lignes sans rien écrire :

```bash
cd "/home/agent-47/Téléchargements/GNU---Gestion-des-notes-Universitaires/backend"
php artisan gnu:import-account-requests storage/app/imports/official_2025_2026/comptes_etudiants_a_completer.csv --role=ETUDIANT --department=INFO
php artisan gnu:import-account-requests storage/app/imports/official_2025_2026/comptes_enseignants_a_completer.csv --role=ENSEIGNANT --department=INFO
```

Quand les prévisualisations sont sans erreur, relancez la commande voulue avec
`--apply`. Elle demande confirmation de la base cible puis demande deux fois le
mot de passe initial sans l’afficher. Vous pouvez saisir la valeur initiale
commune demandée, mais changez-la avant toute utilisation réelle et faites
réinitialiser les mots de passe après validation des comptes.

```bash
php artisan gnu:import-account-requests storage/app/imports/official_2025_2026/comptes_etudiants_a_completer.csv --role=ETUDIANT --department=INFO --apply
php artisan gnu:import-account-requests storage/app/imports/official_2025_2026/comptes_enseignants_a_completer.csv --role=ENSEIGNANT --department=INFO --apply
```

Les logins étudiants sont leurs matricules; les logins enseignants sont leurs
EID. Les codes de profil deviennent `ETU-<matricule>` et `ENS-<EID>`. Le mot de
passe est stocké haché. Toute la série s’importe dans une transaction : une
erreur annule l’ensemble.

## Lier les comptes aux études et aux enseignements

Un compte n’est pas une affectation pédagogique. Après approbation des demandes :

1. l’agent inscrit les étudiants à leur classe/niveau et valide leur inscription;
2. l’agent rattache chaque enseignant à la classe et aux codes EC/UE voulus depuis
   **Comptes & affectations**, après avoir complété et vérifié le CSV de
   répartition;
3. l’enseignant se connecte ensuite avec son EID, choisit les enseignements
   proposés selon le workflow de GNU et peut traiter les notes.

Le CSV de répartition est une aide de saisie, pas une source autorisant à créer
des affectations directement : les codes et l’année doivent correspondre au
catalogue GNU approuvé. Les EID manquants ou les codes absents doivent être
résolus avant l’affectation.
