# 01 — Inventaire du projet

Date de l'audit : 13 octobre 2026. Phase strictement en lecture seule.

## Racine et état Git

Racine observée : `/home/agent-47/Téléchargements/GNU---Gestion-des-notes-Universitaires`.

- Branche : `main`.
- Dernier commit observé : `aca9838 feat: sauvegarder le catalogue académique et le frontend GNU`.
- Le dépôt contient encore un grand ensemble de suppressions non indexées correspondant à l'ancienne organisation ; ces suppressions n'ont pas été modifiées durant l'audit.
- Le remote `origin` pointe vers le dépôt GitHub du projet.

## Arborescence pertinente

| Chemin | Constat |
|---|---|
| `frontend/` | Application Flutter Web actuelle, pages, fonctionnalités, modèle en mémoire et tests. |
| `backend/` | Contient seulement `.gitkeep` dans la version courante. |
| `docs/imports/` | Scripts SQL, CSV académiques et extracteur des EC. |
| `docs/rapport_avancement_gnu.tex/pdf` | Rapport d'avancement généré. |
| `sauvegardes/ancienne-version-2026-10-12/source/` | Ancienne application Flutter, backend Laravel, schéma PostgreSQL et spécifications. |
| `HARMONISATION_*.pdf` | Sources des programmes Licence et Master. |
| `.git/` | Historique Git et remote configuré. |

## Composants importants

La version courante contient `frontend/lib/main.dart`, `pages.dart`, `features.dart`, `domain.dart`, `ui.dart` et `dialogs.dart`. L'ancien backend Laravel est présent uniquement dans la sauvegarde, sous `GNU/GNU_Backend/`. Aucun backend Laravel actif n'est présent à la racine courante.

## Conclusion

Le projet actuel est une base Flutter + scripts/documentation PostgreSQL. L'intégration Laravel existe comme sauvegarde, mais n'est pas exposée comme composant actif à la racine.
