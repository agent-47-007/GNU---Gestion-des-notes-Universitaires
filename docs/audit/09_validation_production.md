# Analyse de préparation et validation en production

**État au 15 octobre 2026 — verdict : non prêt pour la production.**

Cette analyse porte sur le code et les preuves disponibles dans le dépôt. Aucun
URL, accès, identifiant de compte ou accès à une base de production n'est fourni
ici. Par conséquent, aucun parcours ne peut être qualifié de validé en
production. Les observations locales historiques sont identifiées comme telles
et ne constituent pas une preuve sur le système de l'établissement.

## État confirmé dans le dépôt

| Domaine | Présence dans le code | Validation production |
|---|---|---|
| Connexion étudiant, profil, fermeture de session | Routes Sanctum et client Flutter | Non réalisée : cible et compte autorisé absents |
| Inscription de compte étudiant | Aucun parcours accessible ; la route publique et le formulaire ont été désactivés | Source d'identité probante et mécanisme d'activation à définir avant toute réouverture. Le matricule seul ne suffit pas. |
| Profil, notifications, inscriptions pédagogiques | Routes et vues étudiantes connectées présentes | Non réalisées sur un compte de production ; exigent un étudiant rattaché à une inscription de classe et des référentiels cohérents |
| Résultats, rattrapages, requêtes | Routes et rendus étudiants présents | Non réalisés sur des données publiées. La base consultée précédemment ne contenait aucun bulletin courant. |
| Impression et téléchargement du relevé | Génération côté Flutter depuis le contenu reçu | Web compilé historiquement, sans validation d'impression ni d'enregistrement de fichier sur appareils réels |
| Parcours enseignant | Écrans Flutter historiques; lectures API ajoutées pour affectations et plans | Lectures filtrées par titulaire; notes et édition de plans absentes |
| Saisie, contrôle et transmission des notes | Simulation côté Flutter ; tables académiques existantes | Absent côté API, donc impossible à valider |
| Traitement de requêtes par enseignant / agent | Pas de workflow API complet | Absent |
| Calcul, gel et publication des résultats/bulletins | Écrans locaux ; endpoints serveur absents | Absent |
| Structure et catalogue en écriture | Référentiels API en lecture seule | Création, modification et validation métier absentes |
| Comptes agent | Aucune route exposée ; les contrôleurs/requêtes de comptes sont des squelettes (`AccountController` vide, demandes non autorisées) | Indisponible |

## Inventaire des parcours par acteur

| Acteur | Écrans visibles dans le projet Flutter | Opérations serveur disponibles | État réel |
|---|---|---|---|
| Étudiant | Vue d’ensemble, notes/bulletins, guide, inscription pédagogique, requêtes, rattrapages, profil/notifications | Connexion, profil, inscription pédagogique, résultats publiés en lecture, dépôt/lecture de requêtes et justificatifs, rattrapages en lecture, notifications, mise à jour du courriel | Seul parcours client connecté effectivement accessible. Les pages reliées à l’API exigent un profil et une inscription de classe cohérents. Le guide est statique. |
| Enseignant | Classes/matières, saisie des notes, plans d'évaluation, requêtes, rattrapages | `GET profil/enseignant`, `GET enseignant/affectations`, `GET enseignant/affectations/{affectation}/plan-evaluation` | Les deux lectures métier filtrent sur l'affectation active du titulaire. Aucun accès aux notes, aucun endpoint d'écriture, et aucune interface connectée enseignant. |
| Agent | Structure/programmes, comptes/affectations, bulletins, audit, inscriptions, publication | Profil en lecture ; la route de décision répond `503` en attendant la définition du périmètre agent | Aucun espace connecté. Pas de création de comptes, saisie de notes, calcul, publication, catalogue en écriture ou audit consultable. |

Les vues enseignant/agent et les anciennes pages Laravel/maquettes ne sont pas
des fonctions connectées. Leurs routes Laravel sont désactivées ; leurs fichiers
restent dans le dépôt à titre de référence. La connexion Flutter est explicitement
limitée au rôle étudiant malgré les profils de lecture API prévus pour les trois
rôles.

Le schéma PostgreSQL documenté contient des tables pour les notes, évaluations,
bulletins, requêtes, rattrapages, publications et journaux. La présence de tables
ne prouve ni l'existence des règles métier applicatives, ni la sécurité des
opérations, ni la publication de résultats.

## Routes réellement déclarées

Les routes ci-dessous sont déclarées dans `backend/routes/api.php` ; cette
présence ne prouve pas qu'elles ont répondu correctement sur une cible distante.

- **Accès public** : `POST auth/login`. Il n'existe pas de route publique
  d'inscription ; le parcours et l'ancien contrôleur ne sont pas exposés.
- **Session** : `GET auth/me`, `POST auth/logout`, `POST auth/logout-all`,
  `PUT auth/password`.
- **Référentiels en lecture** : années, filières, spécialités, niveaux,
  semestres, classes, UE et EC sous `GET referentiels/*`.
- **Étudiant** : `GET/PUT etudiant/inscriptions`,
  `POST etudiant/inscriptions/soumettre`, `GET etudiant/resultats`,
  `GET/POST etudiant/requetes`, téléchargement des justificatifs,
  `GET etudiant/rattrapages`, notifications en lecture/marquage et mise à jour
  du profil.
- **Agent** : `PATCH agent/inscriptions/{inscriptionClasse}/semestre/{semestre}`
  répond `503` pour un compte agent autorisé. La mutation est volontairement
  désactivée : aucun périmètre par classe/département n'est défini et l'API ne
  fournit pas de file d'attente.
- **Enseignant** : `GET enseignant/affectations` et
  `GET enseignant/affectations/{affectation}/plan-evaluation` exposent les
  affectations actives du titulaire et le plan courant avec contrôle du total
  de pondérations. Aucune route de saisie/transmission des notes ou traitement
  pédagogique des requêtes n'est disponible.
- **Agent / administration** : aucune route métier pour gérer le référentiel en
  écriture, calculer les résultats, générer/geler un bulletin, publier les notes,
  planifier les rattrapages ou consulter le journal d'audit.
- **Interface Web Laravel historique** : aucune route de vue n’est enregistrée.
  Le site connecté à livrer est le client Flutter.

Les règles acceptées pour le calcul pondéré des notes sur 20 et l'admissibilité
aux rattrapages sont maintenant codées dans `backend/config/academic.php` et
`backend/app/Services/AcademicRules.php`. Leur moteur de calcul ne persiste pas
encore de notes. Les règles GPA/MGP, crédits acquis dans les données historiques
et admission restent à formaliser; elles ne sont pas déduites du seuil 10/20.

La route PATCH de décision agent répond `503` pour un agent authentifié : le
périmètre par classe ou département est absent. Cette autorisation doit être
spécifiée et vérifiée avant toute activation réelle.

## Synchronisation et visibilité constatées dans le code

- Une soumission d’inscription passe par la base dans une transaction et pose
  `SOUMISE`. La revue agent est désactivée avec `503` tant que le périmètre
  d'autorisation n'est pas défini; aucune décision ni notification de revue ne
  peut être produite par ce parcours. L’étudiant relit son état via GET.
- Le dépôt étudiant d’une requête crée une requête `SOUMISE` et son justificatif
  éventuel. Aucun acteur enseignant/agent ne peut la traiter via l’API ; la
  décision et la visibilité croisée sont bloquées.
- Aucune opération API ne permet à un enseignant de saisir/transmettre une note
  ou à un agent de calculer/publier un bulletin. Les démonstrations locales ne
  sont pas synchronisées avec PostgreSQL et ne constituent pas une preuve.
- Les contrôles de rôle existent sur les routes étudiantes. La route de décision
  agent répond `503` sans mutation jusqu'à définition et contrôle du périmètre.
  Aucun essai avec des jetons de rôles distincts n’a été exécuté ; l’isolation
  réelle par compte/classe reste à prouver en préproduction.

## Retrait de l'accès démo dans l'interface

L'accueil Flutter ne propose plus le choix libre d'un rôle ni le bouton
d'exploration sans compte. Il mène à l'authentification étudiante ; la création
de compte libre est désactivée dans le client et dans les routes API et Web.
Une session absente ne peut plus afficher les données du
`DemoStore` dans le portail. Les profils enseignant et agent ne sont donc pas
présentés comme des espaces réels accessibles.

Le code de démonstration historique et les fichiers de tests restent dans le
dépôt ; ils ne sont pas des données de production et ne doivent pas être
présentés comme des parcours opérationnels. Les tests automatisés ne remplacent
pas la validation sur une cible réelle. Cette modification de l'accueil ne
complète pas les fonctions serveur manquantes.

## Conditions bloquantes avant mise en production

1. Fournir une cible de préproduction représentative puis une cible de
   production identifiées, leurs domaines HTTPS, les origines CORS autorisées,
   et une configuration `GNU_API_BASE_URL` non locale.
2. Configurer les secrets de production hors du dépôt : `APP_KEY`, connexion
   PostgreSQL, chiffrement/TLS, durée de jeton, stockage des fichiers,
   journalisation, sauvegardes et stratégie de restauration.
3. Définir une source institutionnelle de vérité et une preuve à usage limité
   (activation contrôlée par la scolarité, code d'activation à usage unique ou
   équivalent). La route est désactivée ; ne pas la réactiver tant que cette
   preuve n'est pas conçue, limitée, journalisée et vérifiée.
4. Spécifier et implémenter les endpoints et autorisations enseignant / agent,
   les affectations, la saisie et transmission, les décisions de requêtes, les
   règles officielles de calcul, le gel versionné et la publication.
5. Vérifier les règles acceptées contre le règlement de l'établissement et
   résoudre les écarts de crédits consignés dans
   `docs/audit/05_audit_regles_metier.md`. Le seuil de rattrapage applicatif est
   fixé à 5/20 inclus et 10/20 exclu; aucune variable de seuil externe n'est
   attendue. Les règles GPA/MGP et admission restent bloquées.
6. Disposer de comptes de recette dédiés pour chaque rôle et de jeux de données
   autorisés, anonymisés ou explicitement approuvés. Ne pas créer de faux
   comptes, notes ou bulletins dans la base de production.
7. Vérifier l'isolation des données par compte, classe et rôle, les limites
   d'import de justificatifs, les sauvegardes/restaurations, la supervision et
   la procédure de retour arrière avant d'ouvrir le service.

`backend/.env.example` est une configuration locale. Le nouveau
`backend/.env.production.example` ne contient volontairement aucun secret ni
domaine et laisse les valeurs indispensables vides. Au démarrage avec
`APP_ENV=production`, Laravel refuse une configuration sans clé, URL HTTPS,
base PostgreSQL distante, vérification TLS et origine CORS HTTPS explicite.

La build Web de production se lance par `bash tool/build_production.sh` depuis
`frontend/`, après avoir défini `GNU_API_BASE_URL` sur l'URL HTTPS fournie par
l'établissement et terminée par `/api/v1`. Sans cette valeur, le script échoue ;
une build release directe sans URL affiche un écran bloquant de configuration.

## Procédure reproductible de validation sur préproduction

Ces étapes doivent être exécutées par le responsable de l'environnement avec
des comptes de recette approuvés. Elles ne sont pas des résultats déjà obtenus.

1. Déployer une version candidate sur une base de préproduction isolée, après
   sauvegarde et revue des migrations. Vérifier domaine HTTPS, certificat,
   CORS, stockage des fichiers et URL API intégrée au frontend.
2. Vérifier les routes et la connexion à la base sans afficher de secrets :

   ```bash
   cd backend
   php artisan config:cache
   php artisan route:list --path=api
   php artisan tinker --execute='dump(DB::select("select current_database(), current_user"));'
   ```

3. Avec un compte de recette, confirmer connexion, rôle retourné, profil,
   rechargement de page et restauration de session. Vérifier qu'un compte
   désactivé, un jeton expiré ou révoqué ne conserve pas l'accès, puis que la
   déconnexion invalide la session côté serveur.
4. Pour l'étudiant, vérifier l'inscription pédagogique brouillon/soumise,
   notifications, dépôt puis téléchargement d'un justificatif, résultats vides
   puis publiés, contenu figé, rattrapages et rendu d'impression/téléchargement
   sur chaque plateforme prise en charge.
5. Pour l'enseignant et l'agent, ne lancer de recette qu'après livraison de
   leurs endpoints réels : vérifier les affectations, refus d'accès hors
   périmètre, saisie/transmission, décision des dossiers, calcul, validation,
   publication et journal d'audit avec deux comptes/classe distincts.
6. Contrôler les événements serveur et la base : aucun jeton ou mot de passe
   dans les journaux, résultats cohérents avec les règles approuvées, contenu
   publié immuable et traces attribuées au bon acteur.
7. Rejouer le parcours sur le build de production et les appareils/navigateurs
   retenus, puis effectuer un essai documenté de restauration de sauvegarde.
   N'effectuer aucune écriture exploratoire en production.

### Scénarios croisés de recette (non exécutés)

Ces scénarios nécessitent un étudiant et un agent de recette distincts. Ils
n'ont pas été exécutés pendant cette revue.

1. **Soumission d'inscription → revue agent**
   - Préparer un étudiant de recette rattaché à une classe avec un catalogue
     actif et une demande semestrielle `BROUILLON`.
   - L'étudiant enregistre les UE, soumet, puis relit `GET etudiant/inscriptions`
     pour confirmer `SOUMISE`.
   - Un agent authentifié appelle le PATCH de revue : la réponse attendue est
     `503` sans mutation, tant que le périmètre agent et son workflow ne sont
     pas approuvés. Un rôle non agent doit être refusé par middleware.
   - Preuves : version, identifiants non secrets, codes HTTP, statut avant/après
     et absence de transition dans l'état serveur.
   - La propagation décision → notification étudiant ne peut être testée avant
     livraison de la revue autorisée; ne pas la noter comme réussie.
2. **Requête étudiante → traitement acteur**
   - La création et la consultation des requêtes étudiantes existent. Aucun
     endpoint enseignant/agent ne permet de lister, décider ou corriger une
     requête ; la propagation à un autre acteur est donc actuellement bloquée.
     Ne pas marquer ce parcours comme réussi.
3. **Note enseignant → publication agent → bulletin étudiant**
   - Bloqué : aucun endpoint enseignant de saisie/transmission ni endpoint agent
     de calcul/génération/publication n'est déclaré. Les vues correspondantes
     utilisent l'ancien stockage local. Aucun scénario de recette réel n'est
     possible avant implémentation et approbation des règles de calcul.

Pour chaque étape, conserver la date, la version déployée, le rôle du compte de
recette (sans son secret), le résultat attendu/observé et les identifiants de
traces non sensibles. Les preuves doivent venir de la cible elle-même.

## Preuves locales déjà documentées

Le rapport étudiant [`verification_parcours_etudiant.md`](../verification_parcours_etudiant.md)
consigne des vérifications locales antérieures : routes chargées, compilation
Web, analyse Dart et essais simulés. Il indique également explicitement qu'aucun
compte étudiant n'a été utilisé, qu'aucun bulletin courant n'était disponible
dans la base consultée et qu'aucun parcours HTTP étudiant authentifié n'a été
validé. Ces résultats ne sont pas des preuves de production et ne sont pas
réexécutés dans cette analyse.

## Vérifications effectuées pendant cette revue

Le 15 octobre 2026, les commandes suivantes ont été exécutées :

- `php artisan route:list --path=api --except-vendor` : avant le retrait des
  routes d'inscription et comptes incomplètes, 33 routes ; après retrait,
  28 routes affichées.
- `php artisan route:list --except-vendor` : 28 routes et toutes sous `/api/v1` ;
  aucune route de vue Laravel démo n’est publiée.
- `php artisan route:list --path=inscription --except-vendor` : quatre routes
  d’inscription pédagogique uniquement ; aucune auto-création de compte API ni
  route Web `/inscription`.
- `vendor/bin/pint --dirty --format agent` : réussite.
- `php -l` sur les routes API/Web, `AppServiceProvider`, les configurations CORS
  et académiques, et `StudentPortalController.php` : aucune erreur de syntaxe.
- `git diff --check` : aucune erreur d'espacement dans le diff.
- `bash -n tool/build_production.sh` : réussi. Le script refuse l’absence de
  `GNU_API_BASE_URL` et une URL locale (`https://localhost/api/v1`), comme prévu.
- `flutter build web --debug --no-pub --no-wasm-dry-run` : réussi après les
  dernières modifications. C’est une compilation locale de débogage, sans
  cible de production et sans exercice HTTP authentifié.
- `dart analyze lib/main.dart lib/api_client.dart lib/student_portal.dart` :
  l’analyse a produit 22 informations de style (aucune erreur de code affichée),
  puis s’est terminée en erreur en tentant d’écrire le fichier de télémétrie
  dans `/home/agent-47/.dart-tool`, en lecture seule. Ce résultat n’est pas une
  analyse statique réussie.

Aucun scénario de test automatisé ni appel authentifié à un serveur de
production n'a été exécuté dans cette revue. La compilation confirme la
production des artefacts Web, pas le fonctionnement des parcours ni la
conformité de l'environnement distant.

### Contrôles effectués pendant cette mise à jour

- `php artisan route:list --path=api --except-vendor` dans `backend/` : réussi,
  30 routes; les lectures enseignant sont présentes et la route agent est
  protégée par `role:AGENT`, puis renvoie `503` sans mutation.
- `php -l routes/api.php` et `php -l app/Http/Controllers/StudentPortalController.php`
  dans `backend/` : réussis.
- `vendor/bin/pint --dirty --format agent` : le formatter a indiqué `passed`.
- `php artisan test --compact tests/Unit/AcademicRulesTest.php` : 4 tests et
  10 assertions réussis. Ils couvrent pondérations, calcul, absence/manquant et
  seuil/session de rattrapage, sans base de données.
- `flutter test --no-pub` : échec. Le test `student_portal_test.dart` appelle
  `StudentApiClient.register`, méthode absente; plusieurs tests `widget_test.dart`
  attendent encore l'ancien choix de rôles démo. Cette suite n'est pas verte.
- La connexion DB locale en lecture seule a échoué sur `127.0.0.1:5435`.
  Aucun appel API authentifié ni test préproduction n'a été possible.
- `dart format lib/student_portal.dart` n'a pas démarré : le runtime Flutter a
  tenté d'écrire dans son cache global en lecture seule. Ces résultats ne
  démontrent pas la recette croisée en préproduction.

**Décision de livraison : bloquer la mise en production institutionnelle**
jusqu'à réalisation des conditions 1 à 7 et production des preuves sur une
préproduction contrôlée. Aucune opération n'a été effectuée sur une base de
production et aucune donnée académique n'a été créée ou modifiée pendant cette
analyse.

## Classement après inspection du dépôt

### Implémentable avec les contrats et règles actuels

- Parcours étudiant présent : authentification Sanctum, restauration et
  révocation de session, lecture/mise à jour limitée au courriel, inscriptions
  pédagogiques, notifications, requêtes propres au compte et bulletins publiés.
  L'interface relit l'état après les mutations disponibles. Ces parcours restent
  à vérifier avec des comptes de recette.
- L'API des référentiels permet la consultation, mais pas leur administration.
- L'enseignant peut consulter ses affectations actives et les plans d'évaluation
  courants par deux routes protégées par rôle et filtre de titulaire. La
  transmission des notes et l'édition des plans ne sont pas reliées.
- La revue d'inscription agent répond désormais `503` tant que le périmètre
  d'autorisation n'est pas défini et contrôlé côté serveur.

### Bloqué par une décision institutionnelle

- GPA/MGP, admission et résolution des écarts documentés de crédits; le seuil
  10/20 d'acquisition d'une UE n'est pas une règle d'admission annuelle.
- Confirmation des responsabilités de traitement de chaque type de requête
  dans les services de scolarité concernés.
- Procédure contrôlée de création/activation des comptes étudiants : source de
  vérité, preuve d'identité à usage limité, rôle opérateur, approbation, durée et
  révocation. L'auto-inscription demeure désactivée.

Les propositions acceptées (pondérations 100 %, note sur 20, arrondi à deux
décimales, acquisition à 10/20 sans compensation, rattrapage `[5, 10[` et une
session) sont codées dans le moteur de règles. Leur intégration aux notes et
bulletins attend le schéma vérifié et les droits de la base.

### Bloqué par le schéma ou les accès applicatifs

- DDL et contraintes réelles des tables de notes, comptes agents, requêtes,
  audits, publications et rattrapages; le PostgreSQL local configuré ne répond
  pas et aucun script de création complet n'est versionné dans ce dépôt.
- Liaison contrôlée d'un agent à un département et rôle séparé d'administrateur
  système/responsable pédagogique; valeurs actuelles possibles en base et
  autorisation d'ajouter ces rôles non vérifiées.
- Connexion et affichage de l'espace enseignant Flutter; seuls deux endpoints
  de lecture API sont ajoutés, sans client/UI connecté.

### Bloqué par les accès, comptes, données ou environnements externes

- URL HTTPS de préproduction, configuration CORS et paramètres de déploiement ;
- comptes de recette distincts pour étudiant, enseignant affecté, enseignant
  hors périmètre et agent ;
- jeu de données approuvé comprenant affectations, inscriptions, note non
  publiée et bulletin publié ;
- navigateurs/appareils retenus pour vérifier impression et téléchargement.

## Complément de recette croisée reproductible

Tous les scénarios sont **préparés, non exécutés** au 15 octobre 2026. Pour
chaque exécution, consigner date, commit/version, cible et environnement
(`local`, `préproduction` ou `établissement`), rôles et identifiants non
secrets, codes HTTP, statuts avant/après, identifiants de trace, captures
expurgées et résultat attendu/observé. Ne pas enregistrer de jeton, mot de passe
ou donnée personnelle dans les preuves. Un résultat en préproduction ne vaut pas
validation sur le système de l'établissement.

| Scénario | Prérequis et rôles | Étapes et résultat attendu | Preuves / état |
|---|---|---|---|
| Session étudiant | API préproduction et compte étudiant actif approuvé | Connexion; rechargement; vérifier profil; sur banc de recette, révoquer/laisser expirer le jeton puis vérifier le refus; se déconnecter et confirmer son invalidation | Rôle, codes HTTP, état de session et trace expurgée. Préparé, aucun compte/serveur disponible ici |
| Inscription pédagogique | Étudiant avec inscription de classe et catalogue actif; agent seulement après arbitrage du périmètre | Enregistrer puis relire un brouillon; soumettre et relire `SOUMISE`; vérifier que la revue agent retourne actuellement `503` sans mutation | Réponses API et état DB vérifié par responsable. Préparé; revue agent bloquée |
| Note → publication → bulletin | Deux enseignants (affecté et hors périmètre), agent, deux étudiants; classe/matière/affectations et données approuvées; règles de calcul publiées; routes métier livrées | Enseignant affecté consulte et transmet; l'autre obtient un refus même en appel direct; agent contrôle selon workflow; étudiant concerné ne voit rien avant publication et voit le bulletin après; autre étudiant reste refusé; chaque écran est relu après transition | Requêtes/réponses, état DB, versions de publication, audit attribué et vérification des deux comptes. Bloqué: endpoints enseignant et publication absents |
| Bulletins / impression | Étudiant rattaché, bulletin courant publié, plateforme prise en charge | Comparer détail API, contenu figé et version; imprimer et télécharger puis ouvrir le fichier | Version, fichier expurgé, navigateur/appareil et résultat. API présente; appareils réels non testés |
| Requêtes | Étudiant, UE inscrite, justificatif de recette non sensible; responsable et workflow définis | Déposer, relire et télécharger le justificatif; tenter la lecture par un autre étudiant; après livraison du traitement, vérifier décision et notification | ID de requête, statuts, HTTP, audit et notification. Dépôt/lecture étudiant disponibles; traitement acteur bloqué |
| Notifications | Notification émise par une transition de recette | Lire, marquer comme lue, recharger; vérifier statut serveur et comportement d'envoi répété | ID, état avant/après et codes HTTP. Préparé, à exécuter en préproduction |
| Audit agent | Périmètre approuvé, opérations métier livrées et journaux accessibles | Exécuter une action permise; vérifier acteur, objet, date, motif, transition et absence de secrets dans les logs | ID d'audit et vérification DB/logs. Bloqué: opérations et consultation d'audit absentes |
| Rattrapages | Bulletin publié sur 20, étudiant et éventuelle candidature de recette | Vérifier l'admissibilité 5/20 inclus à 10/20 exclu, puis qu'une session déjà utilisée bloque une nouvelle admissibilité | Réponse API et dossier de recette. Règle unitaire testée; API non vérifiée faute d'accès DB; candidature/calendrier non implémentés |

L'établissement doit fournir la source d'identité et le processus d'activation
des comptes, les responsables nominatifs à rattacher aux départements et les
règles GPA/MGP/admission. Le seuil de rattrapage est maintenant fixé par la règle
approuvée dans `config/academic.php`; aucune candidature de rattrapage ou donnée
d'établissement ne doit être fabriquée pour débloquer la recette.
