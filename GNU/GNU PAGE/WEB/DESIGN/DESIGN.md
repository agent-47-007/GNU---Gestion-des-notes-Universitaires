---
name: Academic Ledger
colors:
  surface: '#f8f9ff'
  surface-dim: '#d7dae2'
  surface-bright: '#f8f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f1f3fc'
  surface-container: '#ebeef6'
  surface-container-high: '#e5e8f0'
  surface-container-highest: '#dfe2eb'
  on-surface: '#181c22'
  on-surface-variant: '#564241'
  inverse-surface: '#2d3137'
  inverse-on-surface: '#eef1f9'
  outline: '#897270'
  outline-variant: '#dcc0be'
  surface-tint: '#a03e3d'
  primary: '#6d181b'
  on-primary: '#ffffff'
  primary-container: '#8c2f2f'
  on-primary-container: '#ffaba7'
  inverse-primary: '#ffb3af'
  secondary: '#515f7a'
  on-secondary: '#ffffff'
  secondary-container: '#cfddfe'
  on-secondary-container: '#53617d'
  tertiary: '#503100'
  on-tertiary: '#ffffff'
  tertiary-container: '#6f4600'
  on-tertiary-container: '#f2b665'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#ffdad7'
  primary-fixed-dim: '#ffb3af'
  on-primary-fixed: '#410005'
  on-primary-fixed-variant: '#812728'
  secondary-fixed: '#d7e2ff'
  secondary-fixed-dim: '#b9c7e7'
  on-secondary-fixed: '#0c1b34'
  on-secondary-fixed-variant: '#394761'
  tertiary-fixed: '#ffddb5'
  tertiary-fixed-dim: '#f8bb6a'
  on-tertiary-fixed: '#2a1800'
  on-tertiary-fixed-variant: '#643f00'
  background: '#f8f9ff'
  on-background: '#181c22'
  surface-variant: '#dfe2eb'
  paper-base: '#DEDACB'
  paper-surface: '#F1EEE2'
  ink-primary: '#1B2942'
  ink-slate: '#5B5F66'
  grader-red: '#8C2F2F'
  seal-gold: '#A9762C'
  status-valid: '#3C6E52'
  status-pending: '#C4841F'
  status-missing: '#8C2F2F'
typography:
  display-lg:
    fontFamily: Newsreader
    fontSize: 40px
    fontWeight: '500'
    lineHeight: 48px
    letterSpacing: -0.01em
  display-lg-mobile:
    fontFamily: Newsreader
    fontSize: 32px
    fontWeight: '500'
    lineHeight: 38px
  headline-lg:
    fontFamily: Newsreader
    fontSize: 28px
    fontWeight: '500'
    lineHeight: 36px
  headline-md:
    fontFamily: Newsreader
    fontSize: 22px
    fontWeight: '500'
    lineHeight: 28px
  headline-sm:
    fontFamily: Newsreader
    fontSize: 18px
    fontWeight: '500'
    lineHeight: 24px
  body-lg:
    fontFamily: IBM Plex Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: IBM Plex Sans
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: IBM Plex Sans
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
  label-md:
    fontFamily: IBM Plex Sans
    fontSize: 13px
    fontWeight: '500'
    lineHeight: 18px
    letterSpacing: 0.02em
  code-lg:
    fontFamily: JetBrains Mono
    fontSize: 16px
    fontWeight: '500'
    lineHeight: 20px
  code-md:
    fontFamily: JetBrains Mono
    fontSize: 13px
    fontWeight: '500'
    lineHeight: 18px
  code-sm:
    fontFamily: JetBrains Mono
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 14px
spacing:
  space-2xs: 0.125rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 0.75rem
  space-base: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
  space-2xl: 3rem
  gutter-mobile: 0.75rem
  gutter-desktop: 1.5rem
  margin-mobile: 1rem
  margin-desktop: 2.5rem
---

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
