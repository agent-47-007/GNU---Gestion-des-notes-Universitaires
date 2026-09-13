<?php

namespace App\Http\Controllers;

use Illuminate\View\View;

class ProfilePageController extends Controller
{
    public function show(string $role, string $page): View
    {
        abort_unless(in_array($role, ['etudiant', 'enseignant', 'agent'], true), 404);

        $pages = [
            'etudiant' => [
                'dashboard' => ['title' => 'Tableau de bord étudiant', 'kicker' => 'Portail étudiant · Licence 3', 'intro' => 'Suivez votre progression, vos résultats et les prochaines échéances.', 'type' => 'dashboard', 'nav' => [['label' => 'Vue d’ensemble', 'slug' => 'dashboard'], ['label' => 'Mes relevés', 'slug' => 'releves'], ['label' => 'Inscription pédagogique', 'slug' => 'inscription'], ['label' => 'Mes requêtes', 'slug' => 'requetes']]],
                'releves' => ['title' => 'Relevé de notes & bulletins', 'kicker' => 'Documents officiels · Étudiant', 'intro' => 'Consultez vos résultats publiés et téléchargez vos relevés certifiés.', 'type' => 'table', 'nav' => [['label' => 'Vue d’ensemble', 'slug' => 'dashboard'], ['label' => 'Mes relevés', 'slug' => 'releves'], ['label' => 'Inscription pédagogique', 'slug' => 'inscription'], ['label' => 'Mes requêtes', 'slug' => 'requetes']]],
                'inscription' => ['title' => 'Inscription pédagogique & choix des UE', 'kicker' => 'Année académique 2025 / 2026', 'intro' => 'Sélectionnez vos unités d’enseignement et confirmez votre parcours du semestre.', 'type' => 'form', 'nav' => [['label' => 'Vue d’ensemble', 'slug' => 'dashboard'], ['label' => 'Mes relevés', 'slug' => 'releves'], ['label' => 'Inscription pédagogique', 'slug' => 'inscription'], ['label' => 'Mes requêtes', 'slug' => 'requetes']]],
                'requetes' => ['title' => 'Soumission de requêtes académiques', 'kicker' => 'Assistance administrative · Étudiant', 'intro' => 'Déposez une demande et suivez son traitement par la scolarité.', 'type' => 'form', 'nav' => [['label' => 'Vue d’ensemble', 'slug' => 'dashboard'], ['label' => 'Mes relevés', 'slug' => 'releves'], ['label' => 'Inscription pédagogique', 'slug' => 'inscription'], ['label' => 'Mes requêtes', 'slug' => 'requetes']]],
            ],
            'enseignant' => [
                'dashboard' => ['title' => 'Tableau de bord enseignant', 'kicker' => 'Espace enseignant · Session 2025 / 2026', 'intro' => 'Pilotez vos enseignements, vos groupes et vos transmissions au jury.', 'type' => 'dashboard', 'nav' => [['label' => 'Vue d’ensemble', 'slug' => 'dashboard'], ['label' => 'Saisie & vérification', 'slug' => 'notes'], ['label' => 'Mes UE & EC', 'slug' => 'ues'], ['label' => 'Requêtes étudiantes', 'slug' => 'requetes']]],
                'notes' => ['title' => 'Saisie & vérification des notes', 'kicker' => 'Registre des évaluations · Enseignant', 'intro' => 'Saisissez les composantes CC, TP et SN, puis contrôlez les incohérences avant transmission.', 'type' => 'table', 'nav' => [['label' => 'Vue d’ensemble', 'slug' => 'dashboard'], ['label' => 'Saisie & vérification', 'slug' => 'notes'], ['label' => 'Mes UE & EC', 'slug' => 'ues'], ['label' => 'Requêtes étudiantes', 'slug' => 'requetes']]],
                'ues' => ['title' => 'Unités d’enseignement & éléments constitutifs', 'kicker' => 'Mes enseignements · Enseignant', 'intro' => 'Retrouvez les UE, les groupes et les éléments constitutifs qui vous sont affectés.', 'type' => 'cards', 'nav' => [['label' => 'Vue d’ensemble', 'slug' => 'dashboard'], ['label' => 'Saisie & vérification', 'slug' => 'notes'], ['label' => 'Mes UE & EC', 'slug' => 'ues'], ['label' => 'Requêtes étudiantes', 'slug' => 'requetes']]],
                'requetes' => ['title' => 'Traitement des requêtes académiques', 'kicker' => 'Dossiers à examiner · Enseignant', 'intro' => 'Consultez les demandes qui nécessitent votre avis pédagogique.', 'type' => 'table', 'nav' => [['label' => 'Vue d’ensemble', 'slug' => 'dashboard'], ['label' => 'Saisie & vérification', 'slug' => 'notes'], ['label' => 'Mes UE & EC', 'slug' => 'ues'], ['label' => 'Requêtes étudiantes', 'slug' => 'requetes']]],
            ],
            'agent' => [
                'dashboard' => ['title' => 'Tableau de bord de la cellule informatique', 'kicker' => 'Administration centrale LMD · Cellule informatique', 'intro' => 'Administrez la structure académique, les calculs, les bulletins et les publications.', 'type' => 'dashboard', 'nav' => [['label' => 'Vue d’ensemble', 'slug' => 'dashboard'], ['label' => 'Structure & hiérarchie', 'slug' => 'structure'], ['label' => 'Catalogue des UE', 'slug' => 'catalogue'], ['label' => 'Numérisation & MGP', 'slug' => 'mgp'], ['label' => 'Bulletins & publications', 'slug' => 'bulletins']]],
                'structure' => ['title' => 'Structure & hiérarchie académique', 'kicker' => 'Référentiel institutionnel · Cellule informatique', 'intro' => 'Organisez la hiérarchie Université, Faculté, Département, Filière, Niveau et Classe.', 'type' => 'tree', 'nav' => [['label' => 'Vue d’ensemble', 'slug' => 'dashboard'], ['label' => 'Structure & hiérarchie', 'slug' => 'structure'], ['label' => 'Catalogue des UE', 'slug' => 'catalogue'], ['label' => 'Numérisation & MGP', 'slug' => 'mgp'], ['label' => 'Bulletins & publications', 'slug' => 'bulletins']]],
                'catalogue' => ['title' => 'Catalogue des UE & paramétrage des cours', 'kicker' => 'Paramétrage LMD · Cellule informatique', 'intro' => 'Gérez les unités d’enseignement, les éléments constitutifs, crédits et volumes horaires.', 'type' => 'cards', 'nav' => [['label' => 'Vue d’ensemble', 'slug' => 'dashboard'], ['label' => 'Structure & hiérarchie', 'slug' => 'structure'], ['label' => 'Catalogue des UE', 'slug' => 'catalogue'], ['label' => 'Numérisation & MGP', 'slug' => 'mgp'], ['label' => 'Bulletins & publications', 'slug' => 'bulletins']]],
                'mgp' => ['title' => 'Numérisation des notes & calcul de la MGP', 'kicker' => 'Contrôle des données · Cellule informatique', 'intro' => 'Surveillez les imports, les calculs de moyenne et les anomalies de cohérence.', 'type' => 'table', 'nav' => [['label' => 'Vue d’ensemble', 'slug' => 'dashboard'], ['label' => 'Structure & hiérarchie', 'slug' => 'structure'], ['label' => 'Catalogue des UE', 'slug' => 'catalogue'], ['label' => 'Numérisation & MGP', 'slug' => 'mgp'], ['label' => 'Bulletins & publications', 'slug' => 'bulletins']]],
                'bulletins' => ['title' => 'Génération des bulletins & publication des résultats', 'kicker' => 'Publications officielles · Cellule informatique', 'intro' => 'Préparez les bulletins, contrôlez les PV et publiez les résultats validés.', 'type' => 'cards', 'nav' => [['label' => 'Vue d’ensemble', 'slug' => 'dashboard'], ['label' => 'Structure & hiérarchie', 'slug' => 'structure'], ['label' => 'Catalogue des UE', 'slug' => 'catalogue'], ['label' => 'Numérisation & MGP', 'slug' => 'mgp'], ['label' => 'Bulletins & publications', 'slug' => 'bulletins']]],
            ],
        ];

        abort_if(! isset($pages[$role][$page]), 404);

        return view('spaces.page', ['space' => $pages[$role][$page], 'role' => $role]);
    }
}
