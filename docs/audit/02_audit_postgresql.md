# 02 — Audit PostgreSQL

> **Archive d’audit historique.** Ce document reflète l’état constaté lors de sa rédaction et a été dépassé par les travaux ultérieurs. Pour l’état fonctionnel accepté au 3 novembre 2026 et les seuls prérequis de livraison encore ouverts, consulter [l’état actuel](09_validation_production.md) et [les règles métier](05_audit_regles_metier.md).

## Limitation d'accès

Une connexion directe en lecture seule depuis l'environnement d'audit n'a pas pu être établie (`psql` n'a pas retourné de résultat exploitable). Les chiffres ci-dessous sont donc ceux vérifiés précédemment dans le terminal du responsable du projet et repris comme preuves historiques, pas comme nouvelle interrogation live.

## État documenté

- Base : `gnu_notes`.
- Port utilisé : `5435`.
- Schéma métier : `gnu`.
- Tables observées précédemment : 34 tables, dont `universite`, `faculte`, `departement`, `filiere`, `specialite`, `niveau`, `annee_academique`, `classe`, `ue`, `matiere`, `etudiant`, `enseignant`, `inscription_classe`, `inscription_ue`, `affectation`, `evaluation`, `note`, `bulletin`, `requete`, `candidature_rattrapage`, `publication` et `journal_audit`.
- 73 UE importées ; 121 EC du catalogue importés ; 62 UE activées.
- 35 étudiants INF361-SR ; 35 inscriptions classe validées ; 350 inscriptions UE validées.

## Relations constatées

```mermaid
erDiagram
  FILIERE ||--o{ NIVEAU : contient
  NIVEAU ||--o{ CLASSE : organise
  NIVEAU ||--o{ UE : porte
  UE ||--o{ MATIERE : contient
  CLASSE ||--o{ INSCRIPTION_CLASSE : accueille
  ETUDIANT ||--o{ INSCRIPTION_CLASSE : possède
  INSCRIPTION_CLASSE ||--o{ INSCRIPTION_UE : détaille
  UE ||--o{ INSCRIPTION_UE : concerne
  CLASSE ||--o{ AFFECTATION : reçoit
  MATIERE ||--o{ AFFECTATION : est_affectee
```

## Contrôles et incohérences

La contrainte d'activation impose un à deux EC par UE. Les écarts documentés de crédits restent à traiter avant publication : `INF461` (UE 6, EC 3), `INF561` (UE 3, EC 6) et `INF571` (UE 3, EC 6). Aucun coefficient distinct n'est présent dans les sources harmonisées ; crédits et pondérations d'évaluation doivent rester séparés.

## Conclusion

Le modèle relationnel couvre les domaines attendus. La vérification live et la résolution des trois écarts de crédits sont bloquantes pour déclarer la conformité PostgreSQL complète.
