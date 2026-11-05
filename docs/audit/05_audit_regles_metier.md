# Règles métier et état fonctionnel GNU

**Mise à jour : 3 novembre 2026.** Les choix métier ci-dessous ont été confirmés par le porteur. Celui-ci confirme également que les parcours enseignant, agent et étudiant décrits dans le dépôt sont fonctionnels et acceptés.

| Domaine | Règle retenue | État |
|---|---|---|
| Enseignant | Agit sur ses affectations actives; configure le plan de ses UE et propose le profil d’évaluation dans le cadre autorisé | Implémenté et accepté par le porteur |
| Agent | Agit dans les départements qui lui sont attribués; administre catalogue/classes, inscriptions, routage, numérisation, audit et publication si habilité | Implémenté et accepté par le porteur |
| Plans d’évaluation | Pondérations totalisant 100 %, configurations versionnées et auditées | Implémenté |
| Notes | Sur 20; absence et note manquante gardent des états distincts; calcul arrondi selon les règles centralisées | Implémenté et testé localement |
| Acquisition UE | À partir de 10/20; pas de compensation automatique | Implémenté selon les règles du projet |
| Rattrapage | Admissible si `0 ≤ note < 10`; obligatoire si `note ≤ 7,5`; facultatif si `7,5 < note < 10`; une session | Implémenté et testé aux bornes |
| Publication | Approbation des règles, complétude et habilitation distincte; publication versionnée et auditée | Implémenté et accepté par le porteur |
| Comptes | Pas d’auto-inscription publique; création contrôlée | Implémenté; création de test locale disponible si explicitement activée |

Les pondérations, barèmes, seuils et règles d’admission restent centralisés dans `backend/config/academic.php` et `backend/app/Services/AcademicRules.php`. Toute évolution métier doit être reflétée simultanément dans le cahier des charges, le code et les tests.

## Livraison

Aucune fonctionnalité métier identifiée par le porteur comme manquante ne reste à coder. La mise en service institutionnelle nécessite encore la configuration de l’infrastructure réelle : URL HTTPS API/Web, CORS, secrets, comptes de recette, base isolée, stratégie de sauvegarde/restauration et livraison du build avec l’URL fournie. Voir [l’état de livraison](09_validation_production.md).
