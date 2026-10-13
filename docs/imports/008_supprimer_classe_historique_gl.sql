-- Suppression définitive demandée de la classe historique L3-GL-A.
-- Cible volontairement limitée au code de classe exact.
BEGIN;
SET LOCAL search_path = gnu, public;

CREATE TEMP TABLE cible AS
SELECT id AS classe_id FROM classe WHERE code_classe = 'L3-GL-A' FOR UPDATE;

DELETE FROM candidature_rattrapage
WHERE inscription_ue_id IN (
  SELECT iu.id FROM inscription_ue iu
  JOIN inscription_classe ic ON ic.id = iu.inscription_classe_id
  JOIN cible c ON c.classe_id = ic.classe_id
)
OR evaluation_origine_id IN (SELECT e.id FROM evaluation e JOIN affectation a ON a.id=e.affectation_id JOIN cible c ON c.classe_id=a.classe_id)
OR evaluation_rattrapage_id IN (SELECT e.id FROM evaluation e JOIN affectation a ON a.id=e.affectation_id JOIN cible c ON c.classe_id=a.classe_id);

DELETE FROM decision_requete WHERE requete_id IN (
  SELECT r.id FROM requete r JOIN inscription_ue iu ON iu.id=r.inscription_ue_id
  JOIN inscription_classe ic ON ic.id=iu.inscription_classe_id JOIN cible c ON c.classe_id=ic.classe_id);
DELETE FROM requete WHERE inscription_ue_id IN (
  SELECT iu.id FROM inscription_ue iu JOIN inscription_classe ic ON ic.id=iu.inscription_classe_id
  JOIN cible c ON c.classe_id=ic.classe_id);
DELETE FROM notification WHERE evaluation_id IN (
  SELECT e.id FROM evaluation e JOIN affectation a ON a.id=e.affectation_id JOIN cible c ON c.classe_id=a.classe_id);
-- Les lignes d'un plan actif sont immuables : on repasse uniquement les plans
-- ciblés en brouillon dans cette transaction avant leur suppression définitive.
UPDATE plan_evaluation
SET statut_plan = 'BROUILLON', updated_at = statement_timestamp()
WHERE affectation_id IN (SELECT a.id FROM affectation a JOIN cible c ON c.classe_id=a.classe_id)
   OR inscription_ue_id IN (
     SELECT iu.id FROM inscription_ue iu JOIN inscription_classe ic ON ic.id=iu.inscription_classe_id
     JOIN cible c ON c.classe_id=ic.classe_id);
DELETE FROM ligne_plan WHERE evaluation_id IN (
  SELECT e.id FROM evaluation e JOIN affectation a ON a.id=e.affectation_id JOIN cible c ON c.classe_id=a.classe_id);
DELETE FROM ligne_plan WHERE plan_id IN (
  SELECT p.id FROM plan_evaluation p
  LEFT JOIN affectation a ON a.id=p.affectation_id
  LEFT JOIN inscription_ue iu ON iu.id=p.inscription_ue_id
  LEFT JOIN inscription_classe ic ON ic.id=iu.inscription_classe_id
  JOIN cible c ON c.classe_id=COALESCE(a.classe_id, ic.classe_id));
DELETE FROM historique_note WHERE note_id IN (
  SELECT n.id FROM note n JOIN inscription_ue iu ON iu.id=n.inscription_ue_id
  JOIN inscription_classe ic ON ic.id=iu.inscription_classe_id JOIN cible c ON c.classe_id=ic.classe_id);
DELETE FROM note WHERE inscription_ue_id IN (
  SELECT iu.id FROM inscription_ue iu JOIN inscription_classe ic ON ic.id=iu.inscription_classe_id JOIN cible c ON c.classe_id=ic.classe_id);
DELETE FROM plan_evaluation WHERE inscription_ue_id IN (
  SELECT iu.id FROM inscription_ue iu JOIN inscription_classe ic ON ic.id=iu.inscription_classe_id JOIN cible c ON c.classe_id=ic.classe_id);
DELETE FROM bulletin WHERE inscription_classe_id IN (SELECT ic.id FROM inscription_classe ic JOIN cible c ON c.classe_id=ic.classe_id);
DELETE FROM inscription_ue WHERE inscription_classe_id IN (SELECT ic.id FROM inscription_classe ic JOIN cible c ON c.classe_id=ic.classe_id);
DELETE FROM evaluation WHERE affectation_id IN (SELECT a.id FROM affectation a JOIN cible c ON c.classe_id=a.classe_id);
DELETE FROM plan_evaluation WHERE affectation_id IN (SELECT a.id FROM affectation a JOIN cible c ON c.classe_id=a.classe_id);
DELETE FROM affectation WHERE classe_id IN (SELECT classe_id FROM cible);
DELETE FROM publication WHERE classe_id IN (SELECT classe_id FROM cible);
DELETE FROM session_rattrapage WHERE classe_id IN (SELECT classe_id FROM cible);
DELETE FROM inscription_classe WHERE classe_id IN (SELECT classe_id FROM cible);
DELETE FROM classe WHERE id IN (SELECT classe_id FROM cible);

COMMIT;
