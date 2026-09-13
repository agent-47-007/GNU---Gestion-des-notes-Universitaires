# Provisionnement PostgreSQL du backend Laravel

Exécuter ce provisionnement après `001_creation.sql`, avec le compte administrateur propriétaire du schéma métier et autorisé à créer des rôles. La base cible est `gnu_notes` par défaut; seule l'alternative `gnu_notes_test` est admise pour une instance de recette isolée. Le port par défaut est **5435**.

```bash
PGUSER=postgres bash GNU_PostgreSQL/preparer_backend.sh --password
```

Le mot de passe administrateur est demandé par `psql` si nécessaire; un fichier `.pgpass` protégé est également accepté. L'option `--password` demande ensuite deux fois le mot de passe de `gnu_app` dans une invite masquée. `psql` le chiffre en SCRAM avant de l'envoyer au serveur. Ne pas fournir de secret comme argument de commande, dans le SQL ou dans Git. Sans cette option, un nouveau rôle est créé sans mot de passe et doit être configuré avant la connexion Laravel. Le provisionnement ne modifie ni `pg_hba.conf`, ni la méthode d'authentification du serveur.

L'opération SQL est transactionnelle et peut être relancée pour réappliquer les droits sans effacer les données ni changer le mot de passe. Un rôle `gnu_app` préexistant avec des privilèges d'administration, des objets à son nom ou une appartenance à un autre rôle est refusé. Le schéma technique doit appartenir au même compte administrateur lors des relances. Les fichiers `001_creation.sql`, `002_tests.sql` et `003_droits.sql` restent inchangés.

## Séparation des droits

| Compte / objet | Droits |
|---|---|
| Administrateur de déploiement | Possède et crée les objets SQL métier et techniques |
| `gnu_app` | LOGIN, aucun privilège d'administration ni appartenance à d'autres rôles |
| Schéma `gnu` | USAGE; lecture, insertion et mise à jour selon `003_droits.sql`; aucun DELETE |
| Historiques, journal, publications, bulletins | Lecture seule directe; écritures par les fonctions/triggers existants |
| `gnu_auth.personal_access_tokens` | SELECT, INSERT, UPDATE, DELETE pour Sanctum |
| Séquences | USAGE et SELECT; aucun droit de réinitialisation |

Le provisionnement retire `CREATE` et `TEMPORARY` sur la base, ainsi que `CREATE` sur le schéma `public`, à `PUBLIC` et à `gnu_app`. Sur PostgreSQL 14, cette modification retire également le droit implicite de création dans `public` aux autres rôles; elle convient à cette base dédiée à GNU. Le retrait de `TEMPORARY` empêche les tables temporaires de masquer les relations des fonctions métier `SECURITY DEFINER`. Le script vérifie qu'aucun autre schéma applicatif n'accorde `CREATE` à `gnu_app` par héritage de `PUBLIC`. Les autres schémas existants ne sont pas modifiés.

La table Sanctum est créée directement par le SQL administrateur. Elle contient les colonnes standard, un index morphique, un index d'expiration et une clé étrangère vers `gnu.utilisateur`. Les dates sont en `timestamptz`; seul le modèle utilisateur GNU peut recevoir des jetons. Le champ `token` conserve le condensat SHA-256 produit par Sanctum, jamais le jeton transmis au client.

Laravel doit utiliser un modèle de jeton pointant explicitement vers `gnu_auth.personal_access_tokens`. Aucune table `users`, `migrations`, `sessions`, `cache` ou `jobs` n'est créée. Utiliser les pilotes fichier/synchrone prévus par le backend; **ne pas exécuter `php artisan migrate` avec `gnu_app`**. Les futures évolutions SQL sont exécutées séparément par l'administrateur.

## Contrôle de connexion

Après saisie du mot de passe, la connexion applicative peut être vérifiée sans écriture :

```bash
psql -X -h localhost -p 5435 -U gnu_app -d gnu_notes -W \
  -c 'SELECT current_user, current_database(), count(*) AS utilisateurs FROM gnu.utilisateur'
```

Les identifiants de ce rôle restent uniquement sur le serveur Laravel. Les profils étudiant, enseignant et agent sont authentifiés et autorisés par l'API; ils ne reçoivent jamais les identifiants PostgreSQL.

Sur une instance isolée réservée aux tests, créer `gnu_notes_test`, y installer `001_creation.sql` et y exécuter le provisionnement avec `PGDATABASE=gnu_notes_test`. La recette suivante vérifie les écritures de jetons, leur révocation, la clé étrangère, le trigger d'audit et le refus effectif des suppressions métier et des créations de tables. Elle refuse toute base dont le nom diffère de `gnu_notes_test` :

```bash
psql -X -v ON_ERROR_STOP=1 -h localhost -p "$GNU_TEST_PGPORT" -U postgres -d gnu_notes_test \
  -f GNU_PostgreSQL/005_tests_backend.sql
```

`GNU_TEST_PGPORT` désigne le port de l'instance isolée de recette. Les données fictives sont annulées par `ROLLBACK`; les séquences peuvent avancer.
