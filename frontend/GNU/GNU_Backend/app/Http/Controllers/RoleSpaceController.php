<?php

namespace App\Http\Controllers;

use Illuminate\View\View;

class RoleSpaceController extends Controller
{
    public function show(string $role): View
    {
        abort_unless(in_array($role, ['etudiant', 'enseignant', 'agent'], true), 404);

        $spaces = [
            'etudiant' => [
                'role' => 'ETUDIANT',
                'label' => 'Étudiant',
                'title' => 'Votre parcours, en un coup d’œil.',
                'description' => 'Suivez vos crédits, consultez vos résultats et préparez vos prochaines inscriptions pédagogiques.',
                'eyebrow' => 'Portail étudiant · Licence 3',
                'nav' => ['Vue d’ensemble', 'Mes relevés', 'Inscription pédagogique', 'Mes requêtes'],
                'metrics' => [['label' => 'Crédits validés', 'value' => '126', 'note' => 'sur 180 ECTS'], ['label' => 'Moyenne générale', 'value' => '14.2', 'note' => '/ 20'], ['label' => 'UE suivies', 'value' => '06', 'note' => 'semestre en cours'], ['label' => 'Dossier', 'value' => 'Actif', 'note' => 'année 2025 / 2026']],
                'rows' => ['Mathématiques discrètes', 'Systèmes d’exploitation', 'Réseaux informatiques'],
            ],
            'enseignant' => [
                'role' => 'ENSEIGNANT',
                'label' => 'Enseignant',
                'title' => 'Pilotez vos évaluations.',
                'description' => 'Retrouvez vos groupes, saisissez les notes et transmettez des données contrôlées aux jurys.',
                'eyebrow' => 'Espace enseignant · Session 2025 / 2026',
                'nav' => ['Vue d’ensemble', 'Mes enseignements', 'Saisie des notes', 'Contrôle & transmission'],
                'metrics' => [['label' => 'Cours actifs', 'value' => '08', 'note' => 'ce semestre'], ['label' => 'Groupes', 'value' => '12', 'note' => 'étudiants suivis'], ['label' => 'Saisies à finir', 'value' => '03', 'note' => 'actions requises'], ['label' => 'Sessions jury', 'value' => '02', 'note' => 'à venir']],
                'rows' => ['INF301 · Algorithmique avancée', 'INF305 · Systèmes & réseaux', 'MAT311 · Probabilités'],
            ],
            'agent' => [
                'role' => 'AGENT',
                'label' => 'Cellule informatique',
                'title' => 'Administrez le registre LMD.',
                'description' => 'Structurez les formations, contrôlez les calculs et préparez la publication des résultats officiels.',
                'eyebrow' => 'Cellule informatique · Administration centrale LMD',
                'nav' => ['Structure & hiérarchie', 'Catalogue des UE', 'Numérisation & MGP', 'Bulletins & publications'],
                'metrics' => [['label' => 'Filières actives', 'value' => '18', 'note' => 'dans le registre'], ['label' => 'UE cataloguées', 'value' => '248', 'note' => 'année courante'], ['label' => 'PV à contrôler', 'value' => '07', 'note' => 'sessions ouvertes'], ['label' => 'Serveur', 'value' => '100%', 'note' => 'opérationnel']],
                'rows' => ['L3 Informatique · Session normale', 'Catalogue UE · Mise à jour 2025', 'PV-2025-S1 · Contrôle des signatures'],
            ],
        ];

        return view('spaces.role', ['space' => $spaces[$role]]);
    }
}
