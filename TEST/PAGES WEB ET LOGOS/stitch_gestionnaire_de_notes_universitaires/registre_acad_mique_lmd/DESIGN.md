---
name: Registre Académique LMD
colors:
  surface: '#fef9ea'
  surface-dim: '#dedacb'
  surface-bright: '#fef9ea'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f8f4e4'
  surface-container: '#f2eede'
  surface-container-high: '#ece8d9'
  surface-container-highest: '#e7e2d3'
  on-surface: '#1d1c13'
  on-surface-variant: '#564241'
  inverse-surface: '#323126'
  inverse-on-surface: '#f5f1e1'
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
  background: '#fef9ea'
  on-background: '#1d1c13'
  surface-variant: '#e7e2d3'
  encre: '#1B2942'
  papier: '#DEDACB'
  papier-clair: '#F1EEE2'
  rouge-encre: '#8C2F2F'
  or-sceau: '#A9762C'
  ardoise: '#5B5F66'
  statut-valide: '#3C6E52'
  statut-en-attente: '#C4841F'
  statut-manquant: '#8C2F2F'
typography:
  headline-xl:
    fontFamily: EB Garamond
    fontSize: 48px
    fontWeight: '500'
    lineHeight: 56px
  headline-xl-mobile:
    fontFamily: EB Garamond
    fontSize: 32px
    fontWeight: '500'
    lineHeight: 40px
  headline-lg:
    fontFamily: EB Garamond
    fontSize: 32px
    fontWeight: '500'
    lineHeight: 40px
  headline-md:
    fontFamily: EB Garamond
    fontSize: 24px
    fontWeight: '500'
    lineHeight: 32px
  headline-sm:
    fontFamily: EB Garamond
    fontSize: 20px
    fontWeight: '500'
    lineHeight: 28px
  body-lg:
    fontFamily: IBM Plex Sans
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: IBM Plex Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-sm:
    fontFamily: IBM Plex Sans
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-md:
    fontFamily: Space Mono
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: 0.02em
  label-sm:
    fontFamily: Space Mono
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
    letterSpacing: 0.04em
  data-tabular:
    fontFamily: Space Mono
    fontSize: 15px
    fontWeight: '500'
    lineHeight: 20px
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  space-2xs: 0.125rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
  space-2xl: 3rem
  space-3xl: 4rem
  col-gutter: 1rem
  margin-mobile: 1rem
  margin-desktop: 2.5rem
---

## Brand & Style

The visual narrative is anchored in the administrative reality and gravitas of Cameroonian higher education: the bound physical register, official transcripts (*relevés de notes*), ministerial stamps, and the decisive red ink of an academic jury. Rather than adopting generic SaaS conventions or floating card abstractions, the design system treats the digital viewport as structured archival paper ruled by precise editorial lines.

The aesthetic blends **Academic Brutalism** and **Editorial Precision**. Every line serves a cartographic function within the LMD hierarchy (Licence, Master, Doctorat). The atmosphere evokes authoritative trust, institutional continuity, legal weight, and procedural rigor. Visual noise, skeuomorphic gradients, and superficial elevation are eliminated in favor of high-contrast typography, hairline borders, and intentional color accents that communicate academic status.

## Colors

The chromatic architecture replicates the physical tools of the university registrar:

- **Encre (`#1B2942`)**: Deep blue-black archival ink. Serves as the bedrock color for primary typography, structural frames, major headers, and institutional identity.
- **Papier (`#DEDACB`)**: Warm, authentic base paper stock used for root application canvases.
- **Papier Clair (`#F1EEE2`)**: Unblemished register pages, table bodies, and card-level work surfaces.
- **Rouge-encre (`#8C2F2F`)**: Primary functional accent representing the corrector’s pen. Strictly reserved for critical operations, primary calls to action, and unresolved/missing academic marks.
- **Or-sceau (`#A9762C`)**: Rare institutional gold, reserved for official mentions, honors, certificates, and seals.
- **Ardoise (`#5B5F66`)**: Slate neutral for technical metadata, column dividers, and secondary hierarchy.

Semantic statuses follow strict grading rules:
- **Validé (`#3C6E52`)**: Formal green indicating credit validation.
- **En attente (`#C4841F`)**: Amber signifying pending deliberation or incomplete continuous assessment.
- **Manquant (`#8C2F2F`)**: Corrective red alerting missing scores or administrative holds.

## Typography

Typography establishes an absolute separation between institutional authority, human reading comfort, and raw mathematical records:

1. **Headlines**: Set in an authoritative, sculpted serif style reminiscent of official decrees and university diplomas. Never set in heavy, blunt bolds; medium weights preserve classical proportions.
2. **Interface & Narrative**: Handled cleanly by **IBM Plex Sans**, an industrial sans-serif engineered for clarity across high-density administrative workflows.
3. **Institutional Data & Metrics**: Handled strictly by monospaced tabular typography (**Space Mono**). Student matricules, subject codes (`INF301`), raw numerical marks (`14.50/20`), credits (ECTS), and grade point averages (GPA) must strictly occupy fixed-width slots to guarantee flawless vertical alignment in ledgers and grade reports.

## Layout & Spacing

The layout philosophy mirrors a hardback ledger: tabular, disciplined, and rhythmically aligned along an 8px vertical grid with strict internal ruling.

- **Desktop Framework**: A 12-column grid framed by 40px outer margins and 16px gutters. Structural panels (academic breadcrumbs, departmental navigators) dock rigidly to the viewport boundaries.
- **Mobile Adaptation**: Collapses to a 4-column structure with 16px safe margins. Grade sheets switch from multi-column ledger tables to horizontal scroll rows or tabular ledger cards without losing mono-spaced numerical alignment.
- **Micro-alignment**: Spacing between data cells maintains a dense 8px/12px padding cadence to support uninterrupted horizontal scanning across multi-evaluation criteria (CC, TP, SN).

## Elevation & Depth

This design system deliberately eschews blurred ambient drop shadows and skeuomorphic levitation. Hierarchy is achieved exclusively through **planar stratification, surface contrast, and hairline ruling**:

- **Paper Tiers**:
  - `Papier` (`#DEDACB`) provides the foundation floor.
  - `Papier clair` (`#F1EEE2`) represents active sheets, table records, and interactive panels resting flush against the base.
- **Hairline Ruling**:
  - Structural separators and card boundaries use 1px solid borders in `Ardoise` (`#5B5F66`) at full opacity or softened against paper.
  - Double-ruled hairline borders (1px line, 2px gap, 1px line) in `#1B2942` are reserved for semester summary totals, jury validation stamps, and official headers.
- **Overlays & Modals**:
  - Modal sheets do not cast diffused shadows. They drop with a sharp 1px solid `#1B2942` frame and a solid 4px hard offset shadow (`box-shadow: 4px 4px 0px #1B2942`), reinforcing the tactile nature of physical document blocks.

## Shapes

The shape grammar is severe, surgical, and near-orthogonal. 

- Interactive controls, status tags, and tabular frames use minimal rounding (hard 2px to 4px corners maximum, tokenized as level `1`).
- Pill shapes, rounded bubble buttons, and soft floating circles are strictly forbidden, as they contradict the solemnity of official transcripts and state registers.
- Matricule containers and badge enclosures must remain crisply squared to honor the grid of the monospaced characters they house.

## Components

### Buttons
- **Primary Action (Correction / Publication)**: Background `#8C2F2F` (Rouge-encre), text `#F1EEE2`, border 1px solid `#8C2F2F`, radius 3px. Hover shifts to darkened crimson (`#702323`). Active state depresses slightly with zero blur.
- **Secondary Action (Navigation / Filter)**: Transparent background, 1px border in `#1B2942`, text `#1B2942`. Hover fills with `#1B2942` and text transitions to `#F1EEE2`.
- **Tertiary / Subdued**: Flat `#F1EEE2` surface with 1px hairline `#5B5F66` border.

### Status Badges
Status indicators display as crisp monospaced tags with a dedicated indicator dot:
- Container: Surface `#F1EEE2`, 1px solid border `#5B5F66` (30% alpha), text in monospaced 12px.
- **Validé**: Leading dot `#3C6E52`, text in `#1B2942`.
- **En attente**: Leading dot `#C4841F`, text in `#1B2942`.
- **Manquant**: Leading dot and text in `#8C2F2F` bold mono.

### Academic Breadcrumb (Fil Hiérarchique)
Displays the full institutional lineage:
`[Université] › [Faculté] › [Département] › [Filière] › [Niveau / Classe]`
- Font: `IBM Plex Sans` 13px.
- Separators: `›` rendered in `#5B5F66`.
- Inactive segments: `#5B5F66`. Active terminal leaf: `#1B2942` with 600 weight.

### Data Inputs & Grade Entry Fields
- Text inputs and grade cells are framed by 1px `#5B5F66` borders against `#F1EEE2`.
- Active focus state: Solid 2px outline in `#1B2942`, background stays pure paper-white.
- Numerical grade entry fields enforce tabular monospaced digits, aligned right, with suffix labels (`/20`) fixed in `#5B5F66`.

### Academic Ledger Table (Relevé de Notes)
- Table headers: `#1B2942` background with `#F1EEE2` uppercase serif or mono labels.
- Alternate zebra fills are disallowed; alternating hierarchy is created strictly through 1px horizontal ruled borders in `#5B5F66`.
- Summary rows (Moyenne Générale, Décision du Jury) sit above a double 1px hairline border with bold tabular figures.