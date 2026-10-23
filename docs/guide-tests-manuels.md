# GNU — Guide de prise en main et de tests manuels

**Version de travail : 16 octobre 2026**  
Ce guide décrit le dépôt actuellement présent et aide à vérifier l’application pas à pas. Il s’agit d’un guide de test local, pas d’une autorisation de faire des essais sur la base de production. Compléter les cases et noter les résultats, captures d’écran et anomalies au fil du parcours.

## 1. Créer ses propres comptes de test

Aucun compte de démonstration ni seeder n’est nécessaire. Le portail local crée les comptes dans la base et permet de créer l’agent avec son département, l’enseignant et l’étudiant avec leur classe.

## 2. Préparer un environnement local

Depuis le dépôt :

```bash
cd "/home/agent-47/Téléchargements/GNU---Gestion-des-notes-Universitaires/backend"
```

Vérifier que PostgreSQL est démarré et que la base répond :

```bash
pg_isready -h 127.0.0.1 -p 5435
php artisan migrate:status
```

La base doit déjà contenir le schéma GNU et les migrations requises. Si `migrate:status` échoue, corriger d’abord la connexion à la base locale.

Si le schéma GNU de base a déjà été restauré dans cette base locale et que des migrations Laravel sont en attente, les appliquer une fois depuis `backend/` :

```bash
php artisan migrate --no-interaction
```

Cette commande ne crée pas le schéma universitaire initial à partir d’une base vide. Ne lancez pas `migrate:fresh` ni `db:wipe` pour préparer vos essais.

Vérifier les réglages sans publier de secrets : dans `backend/.env`, confirmer `APP_ENV=local`, `DB_HOST=127.0.0.1`, `DB_PORT=5435`, `DB_DATABASE=gnu_notes`, puis fournir les paramètres PostgreSQL locaux adéquats. Ne pas copier un `.env` de production dans cet environnement.

### Activer le portail local de création des comptes

Dans `backend/.env`, garder `APP_ENV=local` et configurer une connexion de création séparée, avec un compte PostgreSQL local autorisé à créer les acteurs et leurs rattachements. Son nom d’utilisateur doit être différent de celui de l’API (`DB_USERNAME`). Exemple :

```dotenv
GNU_ENABLE_LOCAL_TEST_ACCOUNT_PORTAL=true
GNU_LOCAL_SETUP_DB_HOST=127.0.0.1
GNU_LOCAL_SETUP_DB_PORT=5435
GNU_LOCAL_SETUP_DB_DATABASE=gnu_notes
GNU_LOCAL_SETUP_DB_USERNAME=gnu_setup
GNU_LOCAL_SETUP_DB_PASSWORD=mot-de-passe-local-du-compte-setup
```

Si ce rôle de connexion n’existe pas encore, un administrateur PostgreSQL local doit le créer une seule fois. Ouvrir `psql` avec le compte administrateur local :

```bash
psql -X -h 127.0.0.1 -p 5435 -U postgres -d gnu_notes
```

Dans `psql`, exécuter les droits minimaux ci-dessous (`\password` demande le mot de passe sans l’afficher) :

```sql
CREATE ROLE gnu_setup LOGIN;
\password gnu_setup
GRANT CONNECT ON DATABASE gnu_notes TO gnu_setup;
GRANT USAGE ON SCHEMA gnu TO gnu_setup;
GRANT SELECT ON gnu.departement, gnu.classe, gnu.utilisateur, gnu.etudiant, gnu.enseignant TO gnu_setup;
GRANT INSERT ON gnu.utilisateur, gnu.etudiant, gnu.enseignant, gnu.inscription_classe, gnu.agent_departement TO gnu_setup;
GRANT USAGE, SELECT ON SEQUENCE gnu.utilisateur_id_seq, gnu.etudiant_id_seq, gnu.enseignant_id_seq TO gnu_setup;
```

Les tables `gnu.inscription_classe` et `gnu.agent_departement` doivent exister (migrations appliquées) avant cette étape.

Puis démarrer Laravel :

```bash
php artisan config:clear
php artisan serve --host=127.0.0.1 --port=8000
```

Ouvrir `http://127.0.0.1:8000/local-test-accounts`. Créer d’abord un Agent et choisir son département; puis un Enseignant; enfin un Étudiant en choisissant une classe. Le compte étudiant est rattaché et autorisé à commencer les tests d’inscription pédagogique. Choisir des logins distincts et conserver les mots de passe localement. Le formulaire exige 12 caractères minimum. Ne pas exposer ce portail sur un serveur public.

Ne pas attribuer le droit de publication pour les essais ordinaires : l’aperçu des bulletins suffit. La publication officielle est une action distincte qui fige un résultat et doit être testée uniquement sur des données de test, avec l’habilitation et l’autorisation institutionnelle appropriées.

## 3. Démarrer l’API et l’interface

Terminal 1 — API Laravel (si elle n’est pas déjà lancée pour le portail) :

```bash
cd "/home/agent-47/Téléchargements/GNU---Gestion-des-notes-Universitaires/backend"
php artisan serve --host=127.0.0.1 --port=8000
```

Terminal 2 — interface Flutter Web :

```bash
cd "/home/agent-47/Téléchargements/GNU---Gestion-des-notes-Universitaires/frontend"
flutter pub get
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8780 --dart-define=GNU_API_BASE_URL=http://127.0.0.1:8000/api/v1
```

Ouvrir `http://127.0.0.1:8780`. Choisir l’acteur sur la page d’accueil, saisir son identifiant et son mot de passe, puis se connecter. Si l’API n’est pas joignable, vérifier le terminal backend et l’URL `GNU_API_BASE_URL`.

Pour vérifier l’API, dans un troisième terminal :

```bash
curl -i http://127.0.0.1:8000/api/v1/referentiels/annees-academiques
```

Les routes de référentiel sont protégées par authentification ; une réponse `401` sans jeton est attendue. Pour une vérification authentifiée dans l’interface, se connecter puis consulter les pages du portail. Ne pas coller les jetons de session dans un rapport.

## 4. Parcours de test Agent

Pour chaque étape, noter **Date**, **Compte/rôle**, **Données de test**, **Étapes**, **Résultat attendu**, **Résultat obtenu**, **Capture/ID**, **Anomalie**. Utiliser les cases comme registre de suivi.

### A. Connexion et périmètre

- [ ] Créer un compte Agent dans `/local-test-accounts`, le rattacher au département voulu, puis se connecter avec le login choisi.
- [ ] Vérifier l’arrivée dans l’espace Agent et l’affichage du tableau de bord.
- [ ] Vérifier que les métriques reflètent seulement le département attribué.
- [ ] Vérifier que l’alerte de publication indique une habilitation séparée si le compte n’en a pas.
- [ ] Se déconnecter, puis tenter l’accès à une URL Agent sans session : l’API doit refuser la requête.
- [ ] Se connecter avec un autre rôle et vérifier que les routes Agent ne sont pas accessibles.

### B. Structure académique, classes et catalogue

Menu **Structure & catalogue**. Inspecter la liste des niveaux, UE, éléments constitutifs, années et classes du département.

- [ ] Vérifier que le département Informatique, ses filières et niveaux attendus sont visibles.
- [ ] Vérifier les codes de filière et niveaux, semestres, crédits, états de catalogue et années.
- [ ] Ouvrir une classe et relever son code, son niveau, son année académique et la version du programme.
- [ ] Créer une classe de test seulement si nécessaire, avec un code distinct (par exemple `TEST-INF-L3-2026`), un niveau et une année existants. Vérifier qu’elle apparaît ensuite dans la liste.
- [ ] Créer une UE de test en brouillon ; y ajouter un ou deux EC ; l’activer seulement après vérification du code, du semestre et des crédits.
- [ ] Archiver l’UE de test après le parcours, si aucune inscription/affectation ne la référence.

La gestion affichée est circonscrite au périmètre départemental et au catalogue prévu dans l’API. Éviter de créer des doublons du catalogue officiel juste pour tester un formulaire.

### C. Comptes et affectations pédagogiques

Menu **Comptes & affectations**.

- [ ] Vérifier les étudiants inscrits dans les classes du département et les enseignants ayant des affectations.
- [ ] Confirmer que le compte Agent lui-même n’est pas suspendable depuis cet écran.
- [ ] Créer une affectation de test en sélectionnant un enseignant, un EC et une classe compatibles.
- [ ] Vérifier qu’elle apparaît dans la liste Agent et dans **Mes affectations** de l’enseignant.
- [ ] Désactiver/réactiver une affectation de test, puis vérifier l’effet sur le carnet enseignant.
- [ ] Vérifier qu’un utilisateur hors périmètre ou un rôle Agent ne peut pas être modifié comme étudiant/enseignant.

### D. Inscriptions étudiantes

Menu **Inscriptions**.

- [ ] Soumettre une inscription pédagogique depuis un compte étudiant de test, si des UE admissibles sont disponibles.
- [ ] Vérifier que l’inscription soumise apparaît dans la file Agent.
- [ ] Accepter ou refuser avec un motif explicite, selon les choix de l’interface.
- [ ] Vérifier le nouvel état depuis le compte Agent et le compte Étudiant.
- [ ] Réessayer une décision déjà prise : l’application doit prévenir d’un état invalide/déjà traité.

### E. Évaluations, notes et transmission (parcours enseignant lié)

Le paramétrage de note et la saisie se font dans le portail **Enseignant**. Il faut une affectation active au préalable.

- [ ] Avec l’enseignant affecté, ouvrir l’EC et définir les évaluations/pondérations (CC, TP, SN) totalisant 100 %.
- [ ] Programmer les dates d’évaluation dans le plan, puis utiliser « Programmer un rattrapage » depuis l’affectation pour planifier une session de rattrapage.
- [ ] Vérifier les cas avec TP et sans TP ; une pondération différente de 100 % doit être refusée.
- [ ] Saisir quelques notes de test, sauvegarder, recharger le carnet et confirmer la persistance.
- [ ] Importer un fichier CSV/XLSX d’essai ; vérifier l’aperçu et les lignes rejetées avant confirmation.
- [ ] Tester une note en attente puis une absence officiellement saisie ; une note manquante reste « en attente » dans le bulletin progressif et n’est pas convertie en zéro. Vérifier le traitement de l’absence selon les règles institutionnelles.
- [ ] Transmettre les notes, puis vérifier le statut transmis et l’audit.
- [ ] Retirer logiquement une note de test, vérifier que l’action est auditée et que l’historique n’est pas effacé physiquement.
- [ ] Ouvrir les bulletins provisoires côté enseignant et vérifier la mise à jour progressive après saisie.

Ne pas utiliser de vraies notes d’étudiants pour le premier exercice d’import. Les valeurs et identités de test doivent être clairement identifiées.

### F. Requêtes étudiantes

- [ ] Créer une requête depuis le portail Étudiant.
- [ ] Vérifier sa présence dans **Requêtes étudiantes** côté Agent.
- [ ] Affecter la requête à un enseignant réellement rattaché à la classe/UE concernée.
- [ ] Vérifier sa présence et son traitement dans l’espace Enseignant.
- [ ] Vérifier la mise à jour visible pour l’étudiant.
- [ ] Tester les cas de requête hors périmètre : ils ne doivent pas être attribuables à un enseignant non concerné.

### G. Rattrapages

- [ ] Programmer une session depuis une affectation enseignant ou depuis le menu Agent, avec une date future.
- [ ] L’ouvrir, la modifier, puis la clôturer selon les transitions disponibles.
- [ ] Vérifier la liste des sessions côté Agent et les étudiants concernés côté Étudiant.
- [ ] Confirmer qu’une session clôturée ne peut pas être modifiée comme si elle était encore ouverte.

### H. Bulletins, MGP et publication

Menu **Bulletins & publications**.

- [ ] Choisir une classe de test et ouvrir l’aperçu des bulletins provisoires.
- [ ] Vérifier qu’un bulletin se construit dès que les notes validées deviennent disponibles.
- [ ] Vérifier le barème officiel, les crédits, les notes en attente, le calcul MGP et l’arrondi au centième.
- [ ] Vérifier qu’un étudiant dont la MGP est inférieure à 2 apparaît en échec tout en ayant un bulletin produit.
- [ ] Vérifier l’aperçu du même bulletin dans les portails Étudiant et Enseignant.
- [ ] **Publication officielle :** ne faire ce test que sur une base et une classe dédiées aux essais, une fois l’aperçu validé et l’habilitation distincte attribuée. Une publication peut créer une version historique officielle.

### I. Audit et comptes

- [ ] Ouvrir **Journal d’audit** après les actions précédentes.
- [ ] Vérifier les actions Agent (création de classe/UE, affectation, décision d’inscription, requête, rattrapage, publication) avec leur auteur et leur horodatage.
- [ ] Vérifier que les données affichées restent dans le périmètre départemental.
- [ ] Si une suspension de compte est testée, utiliser un compte de test non actif dans les autres scénarios ; confirmer que les sessions sont révoquées et que l’agent ne peut pas suspendre son propre compte.

## 5. Parcours de vérification Étudiant et Enseignant

| Rôle | Contrôles principaux |
|---|---|
| Étudiant | Connexion ; fiche/inscription pédagogique ; soumission d’inscription ; notes provisoires et bulletins publiés ; MGP/échec ; requête et justificatif ; notifications ; rattrapages ; mise à jour du profil. |
| Enseignant | Connexion ; affectations ; création/édition du plan d’évaluation ; vérification du total 100 % ; carnet de notes ; import avec aperçu ; sauvegarde et reprise ; transmission ; retrait logique d’une note ; bulletins provisoires ; traitement des requêtes affectées. |
| Agent | Connexion et périmètre ; structure/catalogue ; création de classe/UE ; comptes et affectations ; validation d’inscription ; routage des requêtes ; rattrapages ; aperçu MGP/bulletins ; publication habilitée ; audit. |

Ne pas confondre résultat provisoire (évolutif) et publication officielle (version historisée). La production officielle doit avoir lieu seulement après la vérification des règles de la classe concernée.

## 6. Vérification API de base

Après connexion dans l’interface, les principales routes exposées pour l’Agent sont :

| Fonction | Route |
|---|---|
| Tableau de bord | `GET /api/v1/agent/dashboard` |
| Classes et niveaux | `GET /api/v1/agent/classes`, `GET /api/v1/agent/niveaux` |
| Catalogue UE/EC | `GET /api/v1/agent/catalogue` |
| Comptes et affectations | `GET /api/v1/agent/comptes`, `GET /api/v1/agent/affectations` |
| Inscriptions et requêtes | `GET /api/v1/agent/inscriptions`, `GET /api/v1/agent/requetes` |
| Aperçu et audit | `GET /api/v1/agent/classes/{id}/apercu-bulletins`, `GET /api/v1/agent/audit` |
| Rattrapages | `GET /api/v1/agent/rattrapages/sessions` |

Les écritures correspondantes sont protégées par authentification, rôle Agent, règles de validation et contrôle du périmètre. Utiliser d’abord les écrans pour les essais ; ne pas envoyer directement une requête `POST` de publication à une classe réelle.

## 7. Fiche de suivi à dupliquer pour chaque scénario

```text
ID du test :
Date / version du dépôt :
Rôle et compte de test :
Page ou endpoint :
Préconditions / données utilisées :
Étapes exécutées :
Résultat attendu :
Résultat obtenu :
Statut : PASS / FAIL / BLOQUÉ / NON TESTÉ
Capture ou référence :
Erreur exacte (sans mot de passe ni jeton) :
Correctif / suivi :
```

### Registre global

| Domaine | Tests prévus | PASS | FAIL | Bloqués | Non testés | Notes / références |
|---|---:|---:|---:|---:|---:|---|
| Connexion et rôles | 6 |  |  |  |  |  |
| Agent : périmètre et dashboard | 5 |  |  |  |  |  |
| Structure, classe, catalogue | 8 |  |  |  |  |  |
| Comptes et affectations | 6 |  |  |  |  |  |
| Inscriptions | 5 |  |  |  |  |  |
| Notes et transmission | 8 |  |  |  |  |  |
| Requêtes | 6 |  |  |  |  |  |
| Rattrapages | 4 |  |  |  |  |  |
| Bulletin, MGP, publication | 6 |  |  |  |  |  |
| Audit | 4 |  |  |  |  |  |
| Parcours Étudiant | 8 |  |  |  |  |  |
| Parcours Enseignant | 8 |  |  |  |  |  |

## 8. Transformer les tests en documentation utilisateur

Pour chaque écran, documenter : son objectif, le rôle autorisé, les prérequis, les champs et leur sens, le déroulé normal, les erreurs possibles, le résultat à l’écran, les changements de statut, les règles métier, les preuves/captures et la date de vérification. Numéroter les captures (`AGENT-01`, `ENS-01`, `ETU-01`, etc.) et masquer les identifiants personnels.

Une documentation d’environ cinquante pages peut ensuite s’organiser ainsi : présentation et architecture ; rôles et accès ; installation locale ; guide Agent ; guide Enseignant ; guide Étudiant ; règles de calcul et bulletin ; requêtes/rattrapages ; sécurité/audit ; procédures de test et dépannage. Ce guide constitue la trame de tests et doit être actualisé avec les résultats réels, pas présenté comme preuve que chaque scénario a déjà passé.

## 9. Limites connues à garder dans le compte rendu

- Le portail local de création de comptes n’est disponible qu’avec `APP_ENV=local` et `GNU_ENABLE_LOCAL_TEST_ACCOUNT_PORTAL=true`; le rôle Agent reçoit le département sélectionné et l’étudiant est rattaché à la classe sélectionnée.
- La portée Agent est départementale ; l’application ne présente pas encore un éditeur global complet de toute la hiérarchie institutionnelle.
- L’agent ne reçoit pas automatiquement le droit de publication officielle.
- Les tests d’interface et les contrôles manuels ne remplacent pas les tests automatisés ni une recette de production. Ne pas conclure à une validation production sans l’exécuter sur un environnement dédié et consigner les preuves.
