<?php

namespace App\Http\Controllers;

use Illuminate\View\View;

class MaquetteController extends Controller
{
    /**
     * @return array<int, array{slug: string, title: string, channel: string, role: string, description: string, modules: array<int, string>}>
     */
    private function screens(): array
    {
        return [
            ['slug' => 'tableau-de-bord-etudiant', 'title' => 'Tableau de bord étudiant', 'channel' => 'Web', 'role' => 'Étudiant', 'description' => 'Vue d’ensemble du parcours, des résultats publiés et des prochaines actions académiques.', 'modules' => ['Progression LMD', 'Dernier relevé', 'Actualités du dossier']],
            ['slug' => 'tableau-de-bord-enseignant', 'title' => 'Tableau de bord enseignant', 'channel' => 'Web', 'role' => 'Enseignant', 'description' => 'Pilotage des groupes, des évaluations et des sessions de saisie en cours.', 'modules' => ['Groupes actifs', 'Saisies à terminer', 'Calendrier des jurys']],
            ['slug' => 'saisie-et-verification-des-notes', 'title' => 'Saisie & vérification des notes', 'channel' => 'Web', 'role' => 'Enseignant', 'description' => 'Registre dense pour saisir, contrôler et transmettre les notes par UE.', 'modules' => ['Matrice de notes', 'Contrôle des absences', 'Transmission au jury']],
            ['slug' => 'catalogue-des-ue', 'title' => 'Catalogue des UE & cours', 'channel' => 'Web', 'role' => 'Agent', 'description' => 'Paramétrage des unités d’enseignement, éléments constitutifs et volumes horaires.', 'modules' => ['UE actives', 'Éléments constitutifs', 'Volumes horaires']],
            ['slug' => 'structure-academique', 'title' => 'Structure académique LMD', 'channel' => 'Web', 'role' => 'Agent', 'description' => 'Hiérarchie de référence Université, Faculté, Département, Filière et Classe.', 'modules' => ['Arborescence LMD', 'Années académiques', 'Classes ouvertes']],
            ['slug' => 'numerisation-et-mgp', 'title' => 'Numérisation des notes & calcul MGP', 'channel' => 'Web', 'role' => 'Agent', 'description' => 'Contrôle des imports, calculs de moyennes et alertes de cohérence.', 'modules' => ['Imports reçus', 'Calcul MGP', 'Anomalies']],
            ['slug' => 'deliberations-et-resultats', 'title' => 'Délibérations & publication des résultats', 'channel' => 'Web', 'role' => 'Agent', 'description' => 'Préparation des sessions de jury, signatures et publication officielle.', 'modules' => ['Session ouverte', 'Signatures', 'Publication']],
            ['slug' => 'bulletins-et-releves', 'title' => 'Bulletins & relevés de notes', 'channel' => 'Web', 'role' => 'Étudiant', 'description' => 'Consultation, prévisualisation et impression des documents académiques.', 'modules' => ['Semestres', 'Mentions', 'Téléchargement PDF']],
            ['slug' => 'requêtes-academiques', 'title' => 'Requêtes académiques', 'channel' => 'Web', 'role' => 'Étudiant', 'description' => 'Dépôt et suivi des demandes adressées aux services de scolarité.', 'modules' => ['Nouvelle requête', 'Suivi des statuts', 'Historique']],
            ['slug' => 'profil-et-securite', 'title' => 'Profil, compte & sécurité', 'channel' => 'Web', 'role' => 'Utilisateur', 'description' => 'Informations personnelles, changement de mot de passe et sessions actives.', 'modules' => ['Identité', 'Mot de passe', 'Sessions']],
            ['slug' => 'app-etudiant', 'title' => 'Portail étudiant mobile', 'channel' => 'App', 'role' => 'Étudiant', 'description' => 'Version mobile centrée sur les résultats, l’inscription et les notifications.', 'modules' => ['Accueil mobile', 'Résultats', 'Profil']],
            ['slug' => 'app-enseignant', 'title' => 'Espace enseignant mobile', 'channel' => 'App', 'role' => 'Enseignant', 'description' => 'Accès rapide à la saisie, au contrôle et aux groupes pédagogiques.', 'modules' => ['Mes groupes', 'Saisie rapide', 'Contrôle']],
            ['slug' => 'app-inscription-pedagogique', 'title' => 'Inscription pédagogique mobile', 'channel' => 'App', 'role' => 'Étudiant', 'description' => 'Choix des UE et confirmation de l’inscription pédagogique depuis le mobile.', 'modules' => ['Catalogue', 'Panier d’UE', 'Confirmation']],
            ['slug' => 'app-saisie-rapide', 'title' => 'Saisie rapide des notes', 'channel' => 'App', 'role' => 'Enseignant', 'description' => 'Saisie compacte pensée pour les contrôles et les sessions de terrain.', 'modules' => ['Liste étudiants', 'Note CC/TP/SN', 'Brouillon']],
            ['slug' => 'app-otp-et-mot-de-passe', 'title' => 'Sécurité OTP & mot de passe', 'channel' => 'App', 'role' => 'Utilisateur', 'description' => 'Confirmation OTP, récupération et sécurisation du compte GNU.', 'modules' => ['Code OTP', 'Nouveau mot de passe', 'Appareils']],
            ['slug' => 'app-supervision-lmd', 'title' => 'Supervision de l’avancement LMD', 'channel' => 'App', 'role' => 'Agent', 'description' => 'Indicateurs mobiles sur l’avancement des classes et publications.', 'modules' => ['Avancement', 'Alertes', 'Sessions']],
            ['slug' => 'connexion-academique', 'title' => 'Connexion académique GNU', 'channel' => 'Web', 'role' => 'Utilisateur', 'description' => 'Portail institutionnel de connexion aux espaces GNU.', 'modules' => ['Authentification', 'Guide LMD', 'Support']],
            ['slug' => 'guide-bareme-des-notes', 'title' => 'Guide & barème des notes', 'channel' => 'Web', 'role' => 'Utilisateur', 'description' => 'Référentiel des seuils, mentions et règles de calcul.', 'modules' => ['Barème', 'Mentions', 'Règles']],
            ['slug' => 'academic-ledger', 'title' => 'Academic Ledger', 'channel' => 'Web', 'role' => 'Agent', 'description' => 'Grand livre académique des opérations et des décisions.', 'modules' => ['Journal', 'Registres', 'Audit']],
            ['slug' => 'previsualisation-bulletin', 'title' => 'Prévisualisation & impression du bulletin', 'channel' => 'Web', 'role' => 'Étudiant', 'description' => 'Aperçu officiel du bulletin avant impression ou téléchargement.', 'modules' => ['Aperçu', 'Mentions', 'Export']],
            ['slug' => 'profil-utilisateur-connecte', 'title' => 'Profil utilisateur connecté', 'channel' => 'Web', 'role' => 'Utilisateur', 'description' => 'Espace personnel après authentification et accès aux préférences.', 'modules' => ['Compte', 'Préférences', 'Sécurité']],
            ['slug' => 'traitement-requetes-academiques', 'title' => 'Traitement des requêtes académiques', 'channel' => 'Web', 'role' => 'Agent', 'description' => 'Instruction, affectation et clôture des demandes étudiantes.', 'modules' => ['À traiter', 'Affectées', 'Clôturées']],
            ['slug' => 'parametrage-lmd', 'title' => 'Paramétrage de la structure LMD', 'channel' => 'App', 'role' => 'Agent', 'description' => 'Configuration mobile des niveaux, filières et années académiques.', 'modules' => ['Filières', 'Niveaux', 'Années']],
            ['slug' => 'unites-enseignement-mobile', 'title' => 'Unités d’enseignement mobile', 'channel' => 'App', 'role' => 'Agent', 'description' => 'Consultation mobile des UE et éléments constitutifs.', 'modules' => ['Catalogue UE', 'Crédits', 'Cours']],
            ['slug' => 'bulletins-mobile', 'title' => 'Relevés & bulletins mobile', 'channel' => 'App', 'role' => 'Étudiant', 'description' => 'Consultation mobile des notes et documents publiés.', 'modules' => ['Semestres', 'Bulletins', 'Partage']],
            ['slug' => 'requetes-inscription-mobile', 'title' => 'Requêtes d’inscription mobile', 'channel' => 'App', 'role' => 'Étudiant', 'description' => 'Demandes d’inscription et suivi des décisions sur mobile.', 'modules' => ['Nouvelle demande', 'Pièces', 'Statut']],
            ['slug' => 'requetes-etudiantes-mobile', 'title' => 'Gestion des requêtes étudiantes mobile', 'channel' => 'App', 'role' => 'Étudiant', 'description' => 'Centralisation des demandes et notifications de traitement.', 'modules' => ['Mes requêtes', 'Notifications', 'Historique']],
            ['slug' => 'confirmation-otp-mobile', 'title' => 'Confirmation OTP mobile', 'channel' => 'App', 'role' => 'Utilisateur', 'description' => 'Validation sécurisée d’une identité ou d’une action sensible.', 'modules' => ['Code reçu', 'Renvoyer', 'Vérification']],
            ['slug' => 'profil-compte-etudiant-mobile', 'title' => 'Profil & compte étudiant mobile', 'channel' => 'App', 'role' => 'Étudiant', 'description' => 'Identité, matricule, filière et paramètres du compte étudiant.', 'modules' => ['Identité', 'Parcours', 'Paramètres']],
            ['slug' => 'profil-utilisateur-mobile', 'title' => 'Profil utilisateur mobile', 'channel' => 'App', 'role' => 'Utilisateur', 'description' => 'Profil transversal pour les utilisateurs de l’application GNU.', 'modules' => ['Profil', 'Compte', 'Déconnexion']],
            ['slug' => 'dashboard-enseignant-mobile', 'title' => 'Tableau de bord enseignant mobile', 'channel' => 'App', 'role' => 'Enseignant', 'description' => 'Synthèse mobile des enseignements et saisies à effectuer.', 'modules' => ['Mes cours', 'Alertes', 'Saisies']],
            ['slug' => 'verification-notes-mobile', 'title' => 'Saisie & vérification des notes mobile', 'channel' => 'App', 'role' => 'Enseignant', 'description' => 'Contrôle mobile des notes saisies avant transmission.', 'modules' => ['UE', 'Vérifications', 'Validation']],
            ['slug' => 'mgp-mobile', 'title' => 'Calcul MGP mobile', 'channel' => 'App', 'role' => 'Agent', 'description' => 'Synthèse des calculs de moyenne générale pondérée.', 'modules' => ['Calculs', 'Crédits', 'Anomalies']],
            ['slug' => 'deliberations-mobile', 'title' => 'Délibérations & résultats mobile', 'channel' => 'App', 'role' => 'Agent', 'description' => 'Suivi mobile des jurys, signatures et publications.', 'modules' => ['Jury', 'PV', 'Publication']],
            ['slug' => 'structure-hierarchie-mobile', 'title' => 'Structure hiérarchique LMD mobile', 'channel' => 'App', 'role' => 'Agent', 'description' => 'Navigation mobile dans la hiérarchie académique.', 'modules' => ['Université', 'Faculté', 'Département']],
            ['slug' => 'ue-ecs-mobile', 'title' => 'UE & éléments constitutifs mobile', 'channel' => 'App', 'role' => 'Agent', 'description' => 'Détail des cours, crédits et composantes d’une UE.', 'modules' => ['UE', 'EC', 'Volumes']],
            ['slug' => 'inscription-pedagogique-web', 'title' => 'Inscription pédagogique web', 'channel' => 'Web', 'role' => 'Étudiant', 'description' => 'Choix des unités d’enseignement depuis le portail web.', 'modules' => ['Catalogue', 'Choix', 'Récapitulatif']],
            ['slug' => 'inscription-pedagogique-web-2', 'title' => 'Confirmation des choix d’UE', 'channel' => 'Web', 'role' => 'Étudiant', 'description' => 'Seconde étape de validation de l’inscription pédagogique.', 'modules' => ['Panier', 'Contrôle', 'Confirmation']],
            ['slug' => 'ue-elements-constitutifs-web', 'title' => 'UE & éléments constitutifs web', 'channel' => 'Web', 'role' => 'Agent', 'description' => 'Gestion détaillée des enseignements et de leurs paramètres.', 'modules' => ['UE', 'EC', 'Évaluations']],
            ['slug' => 'supervision-avancement-web', 'title' => 'Supervision de l’avancement web', 'channel' => 'Web', 'role' => 'Agent', 'description' => 'Tableau de supervision des formations et de leur progression.', 'modules' => ['Progression', 'Cohortes', 'Alertes']],
            ['slug' => 'traitement-requetes-web-2', 'title' => 'Traitement & décision des requêtes', 'channel' => 'Web', 'role' => 'Agent', 'description' => 'Écran de décision et de réponse aux requêtes reçues.', 'modules' => ['Dossier', 'Décision', 'Réponse']],
        ];
    }

    public function index(): View
    {
        return view('maquettes.index', ['screens' => $this->screens()]);
    }

    public function show(string $slug): View
    {
        $screen = collect($this->screens())->firstWhere('slug', $slug);
        abort_if($screen === null, 404);

        return view('maquettes.show', ['screen' => $screen]);
    }
}
