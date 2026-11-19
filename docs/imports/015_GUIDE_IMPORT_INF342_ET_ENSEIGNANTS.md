# Données INF342 et répartitions des cours

Les fichiers CSV extraits des pièces sources sont conservés dans
`backend/storage/app/imports/official_2025_2026/`. Ce dossier est ignoré par Git
pour éviter d'envoyer des matricules et des données de personnel dans le dépôt.

## INF342

`inf342_etudiants_valides_source.csv` contient 235 lignes avec matricule unique.
`inf342_lignes_a_confirmer.csv` isole 8 entrées portant `XXXXXXX`; elles ne sont
pas importables tant que les matricules ne sont pas retrouvés. Le classeur n'indique
pas explicitement l'année; 2025-2026 est une hypothèse fondée sur la répartition
Fonda reçue et les métadonnées de date du classeur.

Le script `015_importer_liste_inf342_en_brouillon.sql` rattache à
`INF-L3-2025-2026` uniquement les profils étudiants déjà présents, avec un statut
`BROUILLON`. Il n'invente ni compte, ni nom/prénom découpés, ni choix d'UE. Il
liste avant insertion les matricules sans compte; les comptes doivent être créés
et approuvés par le parcours officiel. La feuille « Présence » n'est pas importée
comme des notes : ses valeurs négatives sont des codes de présence.

Depuis la racine du dépôt, d'abord dans la base de recette :

```bash
psql -X -W -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5435 -U postgres \
  -d gnu_notes_recette -f docs/imports/015_importer_liste_inf342_en_brouillon.sql
```

Après contrôle des résultats et confirmation de l'année/classe, remplacer la base
par `gnu_notes` pour exécuter la même opération dans la base officielle.

## Enseignants et cours

- `repartition_fonda_enseignants_2025_2026.csv` transcrit les codes, intitulés,
  niveaux, semestres et noms d'enseignants tels qu'ils apparaissent dans la source.
  Les noms y sont souvent des noms courts. La colonne de nom complet candidat est
  une piste issue de la répartition ICTD/SIGL 2026-2027, pas une identité confirmée.
- `repartition_ictd_sigl_enseignants_2026_2027.csv` préserve les UE, les deux
  enseignants lorsqu'ils sont indiqués et les noms complets tels qu'imprimés.
  Les lignes sans titre ou avec champs incomplets restent signalées par leur code.

Ces CSV ne créent pas de comptes ni d'affectations dans GNU. Il manque les EID/
identifiants de profil des enseignants et, pour les noms courts Fonda, la
confirmation d'identité. Les comptes doivent passer par la demande d'inscription
et l'approbation de l'administrateur système. Ensuite, la cellule peut valider
les affectations d'UE/EC dans GNU.

## Migrations

Ces fichiers sont des données, pas des migrations de schéma. Vérifier puis
appliquer séparément les migrations Laravel depuis `backend/` :

```bash
cd "/home/agent-47/Téléchargements/GNU---Gestion-des-notes-Universitaires/backend"
php artisan config:clear
php artisan migrate:status --database=pgsql_setup
php artisan migrate --database=pgsql_setup --no-interaction
```

`pgsql_setup` utilise les variables `GNU_LOCAL_SETUP_DB_*` de `backend/.env`.
