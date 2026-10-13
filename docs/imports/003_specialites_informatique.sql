-- GNU - normalisation Filière Informatique / spécialités
-- Migration additive : aucune filière ni donnée existante n'est supprimée.

BEGIN;
SET LOCAL search_path = gnu, public;

CREATE TABLE IF NOT EXISTS specialite (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  code_specialite texte_non_vide NOT NULL,
  libelle_specialite texte_non_vide NOT NULL,
  filiere_id bigint NOT NULL REFERENCES filiere(id),
  actif boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  UNIQUE (filiere_id, code_specialite)
);

ALTER TABLE niveau
  ADD COLUMN IF NOT EXISTS specialite_id bigint REFERENCES specialite(id);

INSERT INTO specialite (code_specialite, libelle_specialite, filiere_id)
SELECT src.code_specialite, src.libelle_specialite, f.id
FROM (VALUES
  ('GL', 'Génie logiciel et systèmes d’information'),
  ('SR', 'Systèmes et réseaux'),
  ('SECU', 'Sécurité informatique'),
  ('DATA', 'Data Science')
) AS src(code_specialite, libelle_specialite)
JOIN filiere f ON f.code_f = 'INF'
JOIN departement d ON d.id = f.departement_id AND d.code_de = 'INFO'
ON CONFLICT (filiere_id, code_specialite) DO UPDATE SET
  libelle_specialite = EXCLUDED.libelle_specialite,
  actif = true,
  updated_at = statement_timestamp();

-- Le tronc commun L1/L2 reste rattaché à la filière Informatique sans
-- spécialité. Les niveaux spécialisés seront affectés explicitement après
-- validation des classes et des procès-verbaux.

COMMIT;
