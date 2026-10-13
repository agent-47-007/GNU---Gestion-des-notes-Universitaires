# Règles de référence du catalogue Informatique

Source de référence : `Extraction_UE_EC_par_niveau.md`, construite à partir des grilles harmonisées Licence/Master 2021.

## Décisions fonctionnelles

1. **Crédits et coefficients** : la base stocke les crédits (`credit_ue`, `credit_matiere`). Les crédits ne sont pas des coefficients de calcul distincts.
2. **Filière et spécialités** : la filière canonique est `INF — Informatique`. `GL`, `SR`, `SECU` et `DATA` sont des spécialités. Une UE de type `Fond` ou `Comp` reste une UE tronc commun et ne reçoit pas de spécialité.
3. **Catégories** : `Fond` et `Comp` sont importés comme `FONDAMENTALE`; `Opt` et les UE de parcours (`SIGL`, `SR`, `SDD`, `Sécu`) sont importés comme `OPTIONNELLE`. Le type de parcours est conservé séparément dans la spécialité lorsque l’information est disponible.
4. **EC du Master** : les grilles ne donnent pas de codes EC officiels. Les codes techniques `INF4111`, `INF4112`, etc. utilisés par l’application sont des identifiants internes dérivés du code UE et du rang, et ne doivent pas être présentés comme des codes réglementaires.
5. **Cardinalité** : une UE active doit avoir un ou deux EC. Les UE sans EC ou avec plus de deux EC restent `BROUILLON` jusqu’à correction documentaire.

## Ambiguïtés corrigées

- `INF241` contient dans la grille des enfants mal préfixés `INF2111/INF2112`; ils sont normalisés en `INF2411/INF2412`.
- `INF251` et `INF261` présentent aussi des préfixes d’EC décalés; le rang et l’UE parent font foi.
- `PPE212` et `PPE312` sont des UE autonomes de compétence/formation professionnelle, pas des EC de l’UE précédente.
- Les EC listés après `INF361` pour `INF371` appartiennent à `INF371`; l’indentation PDF ne doit pas modifier leur rattachement.
- `INF331` est une UE fondamentale de la filière Informatique et non une UE de spécialité GL.

## Contrôles à conserver

- unicité `(niveau, version_programme, code_ue)` ;
- unicité `(ue_id, rang_ec)` et `(ue_id, code_m)` ;
- vérification des crédits EC : somme des crédits EC = crédits UE, sauf anomalie explicitement documentée ;
- vérification des niveaux et semestres avant création des classes annuelles.
