# Règles de référence du catalogue Informatique

Sources de référence : les grilles des programmes harmonisés [Licence 2021](../../HARMONISATION_PROGRAMMES_LICENCE_DEPTINFO_GRILLES-21-07-17-1H%20(Version%202).pdf) et [Master 2021](../../HARMONISATION_PROGRAMMES_MASTER_DEPTINFO_GRILLES-21-11-04-14H.pdf). L’extraction des EC est produite par `extract_ec_catalogue.py`.

## Répartition officielle des UE par niveau

Les 73 codes ci-dessous sont ceux des grilles harmonisées. Le catalogue stocke les semestres 1 et 2 à l’intérieur de chaque niveau; les numéros imprimés par le syllabus sont globaux (1 à 10). La correspondance est L1 1/2, L2 3/4, L3 5/6, M1 7/8 et M2 9/10. Aucun code n’est déplacé d’un niveau.

| Niveau | Semestre du syllabus (semestre du catalogue) | UE officielles |
| --- | --- | --- |
| L1 | 1 (S1) | INF111, INF121, INF131, MAT131, INF141, INF151, PHY161, FBL111 |
| L1 | 2 (S2) | INF112, INF122, INF132, MAT112, INF142, INF152, PPE112 |
| L2 | 3 (S1) | INF211, INF221, INF231, MAT211, INF241, INF251, INF261, FBL211 |
| L2 | 4 (S2) | INF212, INF222, INF232, MAT232, INF242, INF252, PPE212 |
| L3 | 5 (S1) | INF311, INF321, INF331, INF341, INF351, INF361, INF371, INF381, FBL311 |
| L3 | 6 (S2) | INF312, INF322, INF332, INF342, INF352, INF362, INF372, INF382, PPE312 |
| M1 | 7 (S1) | INF411, INF421, INF431, INF441, INF451, INF461, INF471, INF481 |
| M1 | 8 (S2) | INF412, INF422, INF432, INF442, INF452, INF462, INF472, INF482 |
| M2 | 9 (S1) | INF511, INF521, INF531, INF541, INF551, INF561, INF571, INF581 |
| M2 | 10 (S2) | INF500 |

`ue_catalogue.csv` contains these 73 codes exactly once with their level, semester and UE credits. The Master grid is the authority for EC titles and credits where its descriptive section differs. `ec_catalogue.csv` contains two ECs for each of the 72 taught UEs (144 rows); INF500 is the 60-credit research-thesis UE and has no EC in the syllabus.

## Importer le syllabus complet dans GNU

Les UE et EC actifs sont protégés contre la modification par les règles d’intégrité PostgreSQL. Ne pas relancer les imports `002_import_ue_catalogue.sql` et `006_import_ec_catalogue.sql` sur ces lignes actives. Pour charger le syllabus complet et les dix UE dont les EC manquaient (`INF351`, `INF352`, `INF361`, `INF362`, `INF371`, `INF372`, `INF381`, `INF382`, `INF421`, `INF422`), exécuter depuis la racine du dépôt, avec un rôle autorisé à créer des UE et EC dans le schéma `gnu` :

```bash
psql -X -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5435 -U postgres -d gnu_notes -f docs/imports/011_creer_version_2_programme_informatique.sql
```

Le mot de passe PostgreSQL est demandé par `psql`. Cet import crée les 73 UE et 144 EC d’après les CSV et vérifie leurs rattachements et crédits. INF500 est activée comme UE sans EC, conformément au syllabus. Si le catalogue complet existe déjà, activer INF500 dans les catalogues chargés avec :

```bash
psql -X -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5435 -U postgres -d gnu_notes -f docs/imports/012_activer_ue_memoire_inf500.sql
```

Ces opérations ne modifient pas les classes, inscriptions ou notes déjà enregistrées. Dans l’application, la classe reste identifiée par son niveau et son année; le numéro technique du catalogue n’est pas affiché.

## Décisions fonctionnelles

**Classes annuelles** : une classe est créée pour un niveau et une année académique. Le numéro de version reste un détail technique interne pour conserver les inscriptions historiques; il n’est pas présenté aux agents. Une nouvelle classe utilise automatiquement le catalogue actif le plus récent de son niveau. Les affectations d’enseignants sont propres à la classe de l’année.
1. **Crédits et coefficients** : la base stocke les crédits (`credit_ue`, `credit_matiere`). Les crédits ne sont pas des coefficients de calcul distincts.
2. **Filière et spécialités** : la filière canonique est `INF — Informatique`. `GL`, `SR`, `SECU` et `DATA` sont des spécialités. Une UE de type `Fond` ou `Comp` reste une UE tronc commun et ne reçoit pas de spécialité.
3. **Catégories** : le type imprimé dans le syllabus (`Fond`, `Opt`, `Comp`, `SIGL`, `SR`, `SDD`, `Sécu`) et la catégorie d’inscription applicative (`FONDAMENTALE`, `OPTIONNELLE`) sont deux notions distinctes. La catégorie ne détermine jamais le niveau ni le semestre d’une UE. Les sources officielles et leur type doivent être consultés avant toute reclassification.
4. **EC du Master** : les grilles ne donnent pas de codes EC officiels. Les codes techniques `INF4111`, `INF4112`, etc. utilisés par l’application sont des identifiants internes dérivés du code UE et du rang, et ne doivent pas être présentés comme des codes réglementaires.
5. **Cardinalité** : une UE active doit avoir un ou deux EC, sauf INF500 (M2-S2, 60 crédits), UE de mémoire explicitement présente sans EC dans le syllabus.
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
