-- Vérification en lecture seule des affectations pédagogiques d'une année.
-- Usage : psql ... -v annee=2025-2026 -f docs/imports/018_verifier_affectations_enseignants.sql

\if :{?annee}
\else
\set annee 2025-2026
\endif

\echo '1) Résumé par classe/niveau'
SELECT an.libelle AS annee_academique,
       n.code_niv AS niveau,
       c.code_classe AS classe,
       COUNT(a.id) FILTER (WHERE a.actif) AS affectations_actives,
       COUNT(DISTINCT a.enseignant_id) FILTER (WHERE a.actif) AS enseignants_actifs,
       COUNT(DISTINCT a.matiere_id) FILTER (WHERE a.actif) AS EC_couverts
FROM gnu.classe c
JOIN gnu.annee_academique an ON an.id = c.annee_id
JOIN gnu.niveau n ON n.id = c.niveau_id
JOIN gnu.filiere f ON f.id = n.filiere_id
JOIN gnu.departement d ON d.id = f.departement_id
LEFT JOIN gnu.affectation a ON a.classe_id = c.id
WHERE an.libelle = :'annee'
  AND d.code_de = 'INFO'
GROUP BY an.libelle, n.code_niv, c.code_classe
ORDER BY n.code_niv, c.code_classe;

\echo '2) Détail des affectations actives'
SELECT an.libelle AS annee_academique,
       n.code_niv AS niveau,
       c.code_classe AS classe,
       e.eid AS identifiant_enseignant,
       u.nom,
       u.prenom,
       ue.numero_semestre AS semestre,
       ue.code_ue,
       ue.intitule_ue,
       m.code_m AS code_ec,
       m.intitule_matiere AS intitule_ec
FROM gnu.affectation a
JOIN gnu.enseignant e ON e.id = a.enseignant_id
JOIN gnu.utilisateur u ON u.id = e.utilisateur_id
JOIN gnu.classe c ON c.id = a.classe_id
JOIN gnu.annee_academique an ON an.id = c.annee_id
JOIN gnu.niveau n ON n.id = c.niveau_id
JOIN gnu.filiere f ON f.id = n.filiere_id
JOIN gnu.departement d ON d.id = f.departement_id
JOIN gnu.matiere m ON m.id = a.matiere_id
JOIN gnu.ue ue ON ue.id = m.ue_id
WHERE a.actif
  AND an.libelle = :'annee'
  AND d.code_de = 'INFO'
ORDER BY n.code_niv, c.code_classe, ue.numero_semestre, ue.code_ue, m.rang_ec, e.eid;

\echo '3) Enseignants actifs sans affectation active dans cette année'
SELECT e.eid AS identifiant_enseignant, u.nom, u.prenom, u.login
FROM gnu.enseignant e
JOIN gnu.utilisateur u ON u.id = e.utilisateur_id
WHERE u.actif
  AND NOT EXISTS (
      SELECT 1
      FROM gnu.affectation a
      JOIN gnu.classe c ON c.id = a.classe_id
      JOIN gnu.annee_academique an ON an.id = c.annee_id
      WHERE a.enseignant_id = e.id
        AND a.actif
        AND an.libelle = :'annee'
  )
ORDER BY e.eid;
