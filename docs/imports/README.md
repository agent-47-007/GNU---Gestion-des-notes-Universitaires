# Organisation des données par année académique

Les données importées sont classées par période avant leur insertion dans
PostgreSQL. Les années indiquées dans les documents sont conservées telles
quelles ; aucune année n'est déduite lorsqu'elle n'est pas mentionnée.

## Modèle de formation

La structure cible est une filière unique **Informatique**, avec quatre
spécialités : **GL** (Génie logiciel et systèmes d’information), **SR**
(Systèmes et réseaux), **SECU** (Sécurité informatique) et **DATA** (Data
Science). L1 et L2 restent un tronc commun ; la spécialité est affectée au
niveau ou à la classe lorsque la source le précise.

## 2021 — programmes de référence

- Programme harmonisé de Licence Informatique : L1, L2, L3.
- Programme harmonisé de Master Informatique : M1, M2.

Ces documents servent à alimenter le catalogue : filières, niveaux, UE,
matières, crédits, semestres et spécialités. Ils ne représentent pas une
inscription étudiante pour l'année 2021-2022.

## 2024-2025

- Résultats des requêtes additives INF-M2 SR-FON.

Ces données alimenteront les requêtes, décisions et résultats concernés après
transcription contrôlée du PDF scanné.

## 2025-2026

- Procès-verbal récapitulatif Master 1 INF-SR-FON.
- Procès-verbal récapitulatif diplôme Licence 3 INF-SR.

Ces documents alimenteront les étudiants, inscriptions, notes, décisions et
bulletins après contrôle des tableaux scannés.

## Année à confirmer

- Liste définitive des étudiants `INF361 - SR` : 35 étudiants.

Le PDF ne donne pas explicitement l'année académique. Les étudiants sont donc
conservés dans `inf361_sr_students.csv` sans insertion dans une classe annuelle
tant que cette année n'est pas confirmée.
