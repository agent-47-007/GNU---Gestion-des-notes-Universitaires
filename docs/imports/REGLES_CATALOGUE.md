# Règles de référence du catalogue Informatique

Source de référence : `Extraction_UE_EC_par_niveau.md`, construite à partir des grilles harmonisées Licence/Master 2021.

## Décisions fonctionnelles

1. **Crédits et coefficients** : la base stocke les crédits (`credit_ue`, `credit_matiere`). Les crédits ne sont pas des coefficients de calcul distincts.
2. **Filière et spécialités** : la filière canonique est `INF — Informatique`. `GL`, `SR`, `SECU` et `DATA` sont des spécialités. Une UE de type `Fond` ou `Comp` reste une UE tronc commun et ne reçoit pas de spécialité.
3. **Catégories** : `Fond` et `Comp` sont importés comme `FONDAMENTALE`; `Opt` et les UE de parcours (`SIGL`, `SR`, `SDD`, `Sécu`) sont importés comme `OPTIONNELLE`. Le type de parcours est conservé séparément dans la spécialité lorsque l’information est disponible.
4. **EC du Master** : les grilles ne donnent pas de codes EC officiels. Les codes techniques `INF4111`, `INF4112`, etc. utilisés par l’application sont des identifiants internes dérivés du code UE et du rang, et ne doivent pas être présentés comme des codes réglementaires.
5. **Cardinalité** : une UE active doit avoir un ou deux EC. Les UE sans EC ou avec plus de deux EC restent `BROUILLON` jusqu’à correction documentaire.
6. **Inscription semestrielle** : le catalogue contient les UE fondamentales et les options de parcours. Ce nombre d’offres peut donc dépasser six. L’étudiant soumet exactement six UE par semestre; l’application bloque une soumission incomplète ou supérieure à six et signale si le catalogue n’en offre pas assez. M2-S2 conserve l’unique UE de mémoire présente dans la source, plutôt que d’ajouter cinq codes non attestés.

## Contrôle des inscriptions de référence

Les fiches académiques fournies pour L2 et L3 contiennent chacune six UE par semestre. Les codes présents dans ces exemples sont tous résolus dans `ue_catalogue.csv` :

| Niveau | Semestre 1 | Semestre 2 |
| --- | --- | --- |
| L2 | INF211, INF221, INF231, MAT211, INF261, FBL211 | INF212, INF222, INF232, MAT232, INF252, PPE212 |
| L3 | INF311, INF321, INF331, INF341, INF361, FBL311 | INF312, INF322, INF332, INF342, INF362, PPE312 |

Le catalogue conserve les UE optionnelles non retenues dans ces exemples afin que les choix de parcours restent disponibles. Il ne faut pas supprimer ces UE uniquement pour réduire le nombre de cases visibles à six.

Le rapprochement avec les rubriques imprimées sur les fiches a aussi corrigé les catégories : `INF252`, `INF261`, `INF361` et `INF362` sont fondamentales; `PPE212`, `FBL311` et `PPE312` sont optionnelles. `002_import_ue_catalogue.sql` met à jour ces catégories sur les UE déjà présentes lors de sa prochaine exécution.

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
