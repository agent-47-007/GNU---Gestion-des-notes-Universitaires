# Vérification du portail étudiant connecté

État relevé le 15 octobre 2026. Ce document distingue la présence du code d’une
validation sur une base et un compte réels.

Les résultats ci-dessous incluent un état antérieur du code, avant la
désactivation de l’auto-inscription. Pour l’état actuel des routes et des
vérifications, voir [`audit/09_validation_production.md`](audit/09_validation_production.md).

## Parcours recensés

| Parcours | Écran Flutter | Route(s) API | État de preuve |
|---|---|---|---|
| Connexion/déconnexion | Accueil, puis espace étudiant | `POST auth/login`, `GET auth/me`/`profil/etudiant`, `POST auth/logout` | Contrat dans le code ; test HTTP réel à exécuter avec un compte actif |
| Création/activation de compte | Aucun écran client ni route API/web exposée | aucune | Désactivée : source de preuve d’identité institutionnelle et mécanisme d’activation à définir |
| Profil et notifications | Profil & notifications | `GET profil/etudiant`, `PUT etudiant/profil`, `GET etudiant/notifications`, `PATCH etudiant/notifications/{id}/lue` | Appels et états écran présents ; dépend d’un compte ayant un profil étudiant |
| Choix pédagogique | Inscription pédagogique | `GET/PUT etudiant/inscriptions`, `POST etudiant/inscriptions/soumettre` | Appels et flux présents ; exige une inscription de classe non annulée et un catalogue actif |
| Résultats/bulletins | Notes & bulletins | `GET etudiant/resultats?periode=S1\|S2\|ANNUELLE` | Affichage, état vide/erreur, export et impression implémentés ; aucune publication réelle validée ici |
| Requêtes/justificatifs | Mes requêtes | `GET/POST etudiant/requetes`, `GET etudiant/requetes/{id}/justificatif` | Appels et formulaire présents ; dépôt testé seulement avec API simulée, données réelles non testées |
| Rattrapages | Mes rattrapages | `GET etudiant/rattrapages` | Appel et rendu présents ; nécessite bulletin publié et résultats admissibles |
| Guide | Guide & normes | aucune | Page statique locale, pas de données de compte |

Une connexion réelle ouvre les vues API du tableau de bord, du profil, des
inscriptions, résultats, requêtes et rattrapages. Le guide reste statique. Les
espaces enseignant/agent et leur tableau de bord en mode démo ne font pas partie
du périmètre de cette vérification.

## Contrats contrôlés dans le code

- Les routes sont regroupées sous `/api/v1`, avec `auth:sanctum` et `account.active`
  pour les actions authentifiées, et le middleware `role:ETUDIANT` sur le portail.
- La création libre de compte est désactivée dans le client Flutter et les
  routes API et Web. Les comptes doivent être créés ou activés par la procédure
  institutionnelle, puis rattachés aux données académiques vérifiées.
- Le bulletin expose `contenu_fige`; le client affiche les lignes UE reconnues et
  présente le JSON complet si le schéma du snapshot n’est pas reconnu. Le PDF
  téléchargeable/imprimable est un relevé généré par le client à partir des
  snapshots API, pas le fichier original archivé sur le serveur.

## Session et sécurité

Le jeton et sa date d’expiration sont conservés via `flutter_secure_storage`.
Au démarrage, le client rejette un jeton expiré, sinon appelle le profil étudiant
avant d’ouvrir le portail. Un HTTP 401 efface la session et revient à l’accueil ;
la déconnexion appelle le serveur puis efface le stockage local. Aucun jeton
n’est écrit dans les journaux applicatifs.

Pour Flutter Web, servir le site en HTTPS (ou localhost) : le stockage sécurisé
du navigateur dépend d’un contexte sécurisé. Le plugin Web s’appuie sur WebCrypto,
que sa documentation qualifie encore d’expérimental ; les données restent liées
au navigateur et au domaine. Le serveur doit autoriser l’origine Web dans CORS.
L’URL API doit pointer vers le serveur joignable depuis l’appareil,
et non vers `127.0.0.1` quand l’app tourne sur un autre appareil :

```bash
cd frontend
flutter run -d chrome --dart-define=GNU_API_BASE_URL=https://serveur.example/api/v1
```

La valeur par défaut de développement est `http://127.0.0.1:8000/api/v1`.

## Procédure reproductible de validation réelle

1. Configurer `backend/.env` avec les paramètres locaux de PostgreSQL et
   `SANCTUM_EXPIRATION`; ne pas copier ce fichier dans un rapport.
2. Dans `backend/`, vérifier la configuration puis les routes sans lancer de
   migration :

   ```bash
   php artisan config:clear
   php artisan route:list --path=api
   php artisan tinker --execute='dump(DB::select("select current_database(), current_user")); dump(DB::table("gnu.etudiant")->count());'
   ```

3. Démarrer Laravel (`php artisan serve --host=0.0.0.0`) et Flutter avec
   `GNU_API_BASE_URL` correspondant à l’adresse joignable.
4. Utiliser un compte étudiant déjà activé par la procédure institutionnelle et
   rattaché à une inscription de classe valide. Aucun parcours d’auto-inscription
   ne doit être testé ou présenté comme disponible.
5. Tester connexion, rechargement (session restaurée), profil, inscription
   pédagogique brouillon/soumission, résultats avec et sans publication, dépôt
   et téléchargement d’une requête, rattrapages, notifications, impression,
   téléchargement puis déconnexion. Vérifier le retour à l’accueil après
   expiration ou révocation du jeton.
6. En environnement isolé, exécuter `flutter test --no-pub` et
   `flutter build web --no-pub`. Les tests Flutter simulés ne remplacent pas
   l’essai réel ci-dessus.

## Résultats observés le 15 octobre 2026

- `php artisan route:list --path=api` : historique antérieur au retrait des
  routes incomplètes ; le résultat actuel doit être confirmé par la commande de
  recette.
- `php artisan test --compact tests/Feature/StudentPortalRoutesTest.php` : réussi,
  1 test et 13 assertions. Cela prouve le refus sans authentification, pas le
  succès métier d’un compte connecté.
- Lecture Laravel/PostgreSQL en lecture seule (14 octobre) : base `gnu_notes`, rôle `gnu_app`,
  35 étudiants, 36 inscriptions de classe non annulées et 0 bulletin courant.
  Ces comptages prouvent la présence de données d’inscription, pas qu’un
  utilisateur donné possède le profil complet requis.
- `flutter test --no-pub` : réussi, 20 tests, y compris validation de la charge
  d’inscription et restauration/déconnexion/expiration/révocation simulées. Le
  test simulé ne crée aucun compte en base. Les tests de navigation existants
  émettent encore des avertissements de taps hors écran, mais se terminent avec
  succès.
- `flutter build web --no-pub --no-wasm-dry-run` : réussi. L’audit Wasm
  automatique avait échoué (`Unexpected wasm dry run failure (-2)`) avec
  `flutter_secure_storage_web`; l’application est compilée pour le Web
  JavaScript standard. Avertissement restant : icône Cupertino absente.
- `dart analyze` sur les cinq fichiers Dart modifiés : réussi (code retour 0),
  sans erreur ni avertissement ; 22 infos de style sont signalées, principalement
  des accolades recommandées dans l’écran préexistant.
- `flutter analyze` : non concluant, le serveur d’analyse s’arrête avant les
  diagnostics avec `FormatException: Unexpected end of input` sur le canal LSP.
- Parcours HTTP authentifié réel, inscription effective, résultats/rattrapages,
  impression et téléchargement sur appareil : non validés. Le plugin `printing`
  fournit les plateformes Web, Android, iOS, macOS, Windows et Linux, mais seul
  le build Web a été exécuté ici ; le dialogue d’impression dépend de l’appareil.
  Aucun mot de passe étudiant n’a été fourni, aucun compte n’a été créé, et la
  base ne contient aucun bulletin courant. La validation de bout en bout reste à
  faire après configuration d’un compte autorisé et d’un bulletin publié dans
  un environnement de test isolé.

Aucune migration, import, correction ou écriture de données académiques n’a été
effectuée. Les tests simulés peuvent être rejoués sans compte réel ; les essais
HTTP nécessitent les identifiants et la configuration du responsable.
