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

---

*Stage académique ARITED — République du Cameroun*
