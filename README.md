# GNU — Gestion des notes

Première itération démontrable du projet de stage, avec PostgreSQL local.

## Architecture principale

Flutter/Dart → API PHP locale → PostgreSQL local.

Flutter ne se connecte jamais directement à PostgreSQL. L’API applique les validations et appelle les fonctions métier du schéma `gnu`.

## Saisie et vérifications des notes — démonstration

La navigation enseignant ouvre un registre modifiable par UE puis EC. Les plans
d’exemple avec TP (20/30/50) et sans TP (30/70) déterminent les colonnes et les
compteurs. Une cellule vide représente une note manquante ; `ABS` représente une
absence. Les notes numériques se saisissent sur 20, avec point ou virgule.

Le calcul convertit les notes sur 100, applique les pondérations, arrondit chaque
EC à l’entier supérieur, puis calcule l’UE avec les crédits de ses EC et arrondit
à nouveau. Les grades suivent le barème SQL. Le seuil de 35/100 porte sur l’UE
pour l’admission annuelle ; une note faible de CC ne produit pas le statut EL.

Les contrôles et états sont séparés par EC : brouillon, validation, puis
transmission **simulée**. Une modification impose une nouvelle validation.
Les notes manquantes, invalides et les absences normales à régulariser bloquent
la finalisation. Les résultats affichés restent provisoires.

Le bouton de sauvegarde conserve les brouillons de démonstration dans le
navigateur ; sur les autres plateformes, ils sont conservés pendant la session
de l’application. Restaurer un brouillon impose une nouvelle validation. Les
imports/exports Excel et la transmission au Décanat sont simulés. Ce registre
ne lit ni n’écrit encore les notes du serveur.

Vérification : `cd frontend`, puis `flutter test` et `flutter build web`.

## Prérequis locaux

- PostgreSQL démarré sur le port `5435` ;
- base `gnu_notes` existante ;
- schéma `gnu` installé avec `GNU_Creation_PostgreSQL.sql` ;
- PHP avec l’extension `pdo_pgsql` ;
- Flutter, uniquement pour lancer l’interface.

Si la base n’est pas encore installée :

```bash
createdb -p 5435 -U postgres gnu_notes
psql -p 5435 -U postgres -d gnu_notes -v ON_ERROR_STOP=1 -f GNU_Creation_PostgreSQL.sql
psql -p 5435 -U postgres -d gnu_notes -v ON_ERROR_STOP=1 -f database/002_demo.sql
```

## Démarrer l’API sans Docker

```bash
cp .env.local.example .env.local
bash scripts/run-api-local.sh
```

Dans un autre terminal :

```bash
curl http://127.0.0.1:8080/api/health
bash scripts/check.sh
```

Routes principales : `/api/health`, `/api/dashboard`, `/api/classes`, `/api/students`, `/api/students/21T2355/bulletin?period=S1`.

## Démarrer Flutter

```bash
cd frontend
flutter pub get
flutter run -d chrome --dart-define=API_BASE=http://127.0.0.1:8080/api
```

## Docker — optionnel

Docker reste disponible avec `docker compose up --build` pour reproduire une installation isolée, mais il n’est plus nécessaire et ne doit pas être lancé en même temps qu’un PostgreSQL local utilisant le port `5435`.
=======
<<<<<<< HEAD
# gnu_frontend

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
=======
# Gestion des Notes d'une Université — Système LMD

Application Web & Mobile de gestion des notes des étudiants, conçue pour le système LMD (Licence-Master-Doctorat) en vigueur dans les universités du Cameroun.

> Projet réalisé dans le cadre du **stage académique ARITED**
> Présenté par **Ngue Mbong André Fitzgerald** · Encadré par **Dr Thomas Messi Nguele**

---

## 📌 Contexte & problématique

Dans de nombreux départements universitaires, la gestion des notes repose encore sur des procédures manuelles ou semi-automatisées (feuilles de calcul, registres papier), gérées de façon cloisonnée par chaque enseignant ou secrétariat pédagogique. Cela engendre des erreurs de saisie, des délais de publication longs (~7 jours en moyenne) et un manque de traçabilité et de visibilité pour les étudiants.

**Objectif :** centraliser, sécuriser et automatiser la gestion des notes, accessible à tous les acteurs (étudiants, enseignants, agents de la cellule informatique) aussi bien depuis un ordinateur que depuis un smartphone.

## 🎯 Objectifs du projet

- Automatiser la saisie et le calcul des moyennes selon les coefficients des matières (CC / TP / SN)
- Centraliser les données académiques (étudiants, UE, EC, notes) dans une base unique
- Offrir un accès Web et Mobile aux mêmes informations via une architecture commune
- Sécuriser les accès selon les rôles (étudiant, enseignant, agent)
- Générer automatiquement les relevés de notes et bulletins semestriels

## 👥 Les acteurs du système

| Acteur | Rôle principal |
|---|---|
| **Étudiant** | Choisit ses matières/UE, consulte ses notes et son bulletin, soumet une requête en cas de note manquante |
| **Enseignant** | Sélectionne ses matières, saisit les notes, vérifie leur numérisation, traite les requêtes |
| **Agent** (cellule informatique / administrateur) | Gère la structure académique, numérise les notes, calcule la MGP, génère les bulletins, publie les résultats |

Précondition commune aux trois acteurs : **authentification obligatoire** avant toute action.

## 🏫 Le système LMD

```
Université › Faculté › Département › Filière › Niveau (L1–M2) › Classe
```

Pondération des évaluations par matière (EC) :

| Type d'UE | CC | TP | SN |
|---|---|---|---|
| Avec Travaux Pratiques | 20 % | 30 % | 50 % |
| Sans Travaux Pratiques | 30 % | — | 70 % |

## 🔄 Cycle de vie de la publication des notes

1. **Évaluation & saisie** — l'enseignant évalue (CC/TP/SN) et saisit les notes
2. **Transmission** — les notes sont transmises à la cellule informatique
3. **Numérisation & vérification** — numérisation par l'agent, puis vérification par l'enseignant
4. **Calcul & bulletins** — calcul automatique de la MGP et génération des bulletins
5. **Publication & consultation** — publication des résultats, consultation par l'étudiant

*Scénario alternatif :* en l'absence de note, l'étudiant soumet une requête ; l'enseignant la traite et corrige la note, qui repart dans le circuit de numérisation.

## 🗂️ Modèle de données

Le recueil des besoins identifie trois familles d'entités :

- **Structure académique** : Université, Faculté, Département, Filière, Niveau, Classe
- **Pédagogie** : UE, Matière (EC)
- **Acteurs & évaluation** : Enseignant, Étudiant, Inscription, Note, Requête, Bulletin

Le modèle conceptuel de données (MCD) complet est disponible dans `GESTION_DES_NOTES_drawio.pdf`.

## 🛠️ Stack technique

| Besoin | Choix |
|---|---|
| Framework mobile/web | **Flutter** (Dart) |
| Appels HTTP | `dio` |
| Gestion d'état | `flutter_riverpod` |
| Navigation | `go_router` |
| Stockage local | `shared_preferences`, `hive` |
| Modélisation | **UML** (cas d'utilisation, classes, séquence, états) |

Le choix de Flutter permet une seule base de code pour les versions Web et Mobile, avec une interface cohérente pour les trois profils d'utilisateurs.

## 📅 Méthodologie — Sprints

| Sprint | Semaines | Contenu |
|---|---|---|
| **1 — Fondations** | 1–2 | Authentification, structure académique |
| **2 — Saisie & sélection** | 3–4 | Choix des matières, saisie des notes |
| **3 — Traitement & publication** | 5–6 | Numérisation → vérification → calcul → publication |
| **4 — Consultation & réclamations** | 7–8 | Consultation des résultats, requêtes |

## 📁 Structure du dépôt

```
├── DOCS/                      # Recueil des besoins, rapports d'apprentissage (UML, Flutter)
├── DIAGRAMMES/                # Diagrammes UML et MCD (drawio, PDF)
├── TEST/PAGES WEB ET LOGOS/   # Maquettes générées (Stitch) : dashboards, écrans, logos
└── (code source Flutter)      # Première itération de l'application
```

## 📖 Documentation associée

- `RECEUIL_DES_BESOINS.docx` — expression des besoins, dictionnaire de données, entités
- `Rapport_Apprentissage_UML.docx/.pptx` — apprentissage UML appliqué au projet
- `Rapport_Apprentissage_Flutter.docx/.pptx` — apprentissage Flutter appliqué au projet
- `Gestion_des_Notes_Presentation.pptx` — présentation générale du projet
- `GESTION_DES_NOTES_drawio.pdf` — diagrammes et modèle de données

## ⚠️ Points de vigilance

- **Agent = Administrateur** *(résolu)* : l'administrateur de l'application est la cellule informatique, qui agit à travers ses agents.
- **Notion de « salle »** *(à valider)* : synonyme de classe, lieu physique, ou groupe de TD/TP ? À confirmer avec le service de la scolarité avant la suite du développement.


