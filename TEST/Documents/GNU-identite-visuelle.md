# GNU — Identité visuelle

*Gestion des Notes d'une Université — Système LMD*
Web & Mobile · Stage académique ARITED

---

## Concept

L'identité de **GNU** ne part pas d'un habillage logiciel générique : elle part des objets réels du monde académique camerounais — le bulletin, le stylo rouge du correcteur, le sceau administratif, la hiérarchie du système LMD (Université › Faculté › Département › Filière › Niveau › Classe).

Principes directeurs :
- Les surfaces se distinguent par des **lignes fines**, comme un registre relié — pas de cartes flottantes avec ombres.
- Le rouge n'est jamais décoratif : c'est le rouge du stylo qui corrige, utilisé pour l'action **et** pour signaler une note manquante.
- Les données réelles (matricules, codes, notes) s'affichent toujours en **police à chasse fixe**, jamais en texte courant.

---

## Couleurs

### Palette de marque

| Nom | Hex | Usage |
| --- | --- | --- |
| Encre | `#1B2942` | Texte, en-têtes, navigation, marque |
| Papier | `#DEDACB` | Fond de page |
| Papier clair | `#F1EEE2` | Surfaces, tableaux, cartes |
| Rouge-encre | `#8C2F2F` | Actions principales, corrections, notes manquantes |
| Or-sceau | `#A9762C` | Mentions, distinctions — usage rare |
| Ardoise | `#5B5F66` | Texte secondaire, séparateurs, libellés techniques |

### Couleurs sémantiques (statut de note)

| Statut | Couleur | Hex |
| --- | --- | --- |
| Validé | Vert | `#3C6E52` |
| En attente | Ambre | `#C4841F` |
| Manquant | Rouge | `#8C2F2F` |

---

## Typographie

| Rôle | Police | Justification |
| --- | --- | --- |
| Titres | **Fraunces** (serif, graisse 500) | Empattements marqués — registre du diplôme et du document scellé. Jamais en gras appuyé. |
| Interface & texte courant | **IBM Plex Sans** | Dessin technique et net, conçu pour les interfaces de données denses, cohérent web et mobile. |
| Codes, matricules, notes | **IBM Plex Mono** | Chasse fixe : les chiffres s'alignent en colonnes. Réservée aux données du dictionnaire, jamais décorative. |

### Échelle type

| Élément | Police / Graisse | Taille |
| --- | --- | --- |
| H1 | Fraunces 500 | 40–64px |
| H2 | Fraunces 500 | 28px |
| Corps | Plex Sans 400 | 16px |
| Libellé technique | Plex Mono 400 | 11–13px |
| Données (matricule, note) | Plex Mono 400/500 | 14–16px |

**Exemples :**
- Titre : *Bulletin de notes*
- Corps : Votre note de Mathématiques a été publiée par la cellule informatique.
- Donnée : `21A123 · 15.5/20`

---

## Marque

Le symbole traduit la hiérarchie du système LMD : cinq strates qui se resserrent, de l'Université jusqu'à la Classe, la strate du sommet — la plus étroite — marquée en rouge-encre pour représenter le niveau courant.

```
████████████████████████████████████████████████████  Université      (encre 100%)
  ██████████████████████████████████████████████      Faculté         (encre 82%)
    ██████████████████████████████████████            Département     (encre 64%)
      ██████████████████████████                       Filière         (encre 46%)
          ████████████████                              Classe (actif)  (rouge-encre)
```

**Lockup :** symbole + nom **GNU** en Fraunces 500, avec le sous-titre `Gestion des notes · Système LMD` en Plex Mono, petit, en ardoise.

**Règle d'usage :** sur fond papier, le symbole reste en encre. Sur fond encre, il passe entièrement en papier clair ; l'accent rouge devient alors or-sceau pour préserver le contraste.

> Le nom **GNU** est celui retenu par le porteur du projet. Notez qu'il est identique au sigle du projet GNU (logiciel libre, fondation GNU/Linux) — à garder à l'esprit si le produit doit un jour être visible publiquement ou déposé, pour éviter toute confusion avec ce projet préexistant.

---

## Composants

### Boutons

| Type | Style |
| --- | --- |
| Primaire | Fond `#8C2F2F`, texte papier clair, coins légèrement arrondis (3px) |
| Secondaire | Transparent, bordure encre, texte encre |

Exemples : *Publier les résultats* (primaire), *Annuler* (secondaire).

### Badges de statut

Pastille de couleur + libellé en Plex Mono 12px, sur fond papier clair, bordure fine ardoise claire.

- 🟢 `Validé`
- 🟠 `En attente`
- 🔴 `Manquant`

### Fil hiérarchique (navigation)

Texte Plex Sans, séparateur `›` en ardoise, dernier élément en encre gras :

```
Université de Douala › Faculté des Sciences › Informatique › L3 — Classe A
```

### Identifiant

Affiché en encadré fin, Plex Mono 15px :

```
21A123
```

---

## Exemple appliqué — Relevé de notes

**Relevé — Semestre 1** · `MATRICULE 21A123 · L3 INFORMATIQUE`

| Matière | CC | TP | SN | Note | Statut |
| --- | --- | --- | --- | --- | --- |
| Mathématiques | 14 | — | 16 | **15.4/20** | 🟢 Validé |
| Systèmes d'exploitation | 12 | 15 | — | **13.5/20** | 🟠 En attente |
| Réseaux | — | — | — | **—** | 🔴 Manquant |

Lignes fines entre chaque matière, aucune ombre, chiffres alignés en Mono — l'esthétique du registre plutôt que celle de la carte logicielle.

---

*Système de design GNU — v1 · Projet Gestion des Notes d'une Université (Système LMD), stage académique ARITED.*
