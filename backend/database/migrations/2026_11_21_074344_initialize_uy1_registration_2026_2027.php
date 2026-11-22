<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::select("SELECT set_config('gnu.motif', 'Référentiel UY1 et ouverture 2026-2027', true)");
        $university = DB::table('gnu.universite')->where('code_univ', 'UY1')->value('id');
        if ($university === null) {
            throw new RuntimeException('Le référentiel UY1 doit être installé avant cette migration.');
        }
        // Sources: pages institutionnelles UY1 (FS, FALSH, FSE, ENS) et polytechnique.cm/departements.
        // Les départements et formations non confirmés ne sont pas créés.
        $establishments = [
            'FS' => ['Faculté des Sciences', [['BIOC', 'Biochimie'], ['BIOA', 'Biologie et Physiologie Animales'], ['BIOV', 'Biologie et Physiologie Végétales'], ['CHMI', 'Chimie Inorganique'], ['CHMO', 'Chimie Organique'], ['INFO', 'Informatique'], ['MATH', 'Mathématiques'], ['MICR', 'Microbiologie'], ['PHYS', 'Physique'], ['STU', 'Sciences de la Terre et de l’Univers']]],
            'FALSH' => ['Faculté des Arts, Lettres et Sciences Humaines', [['ALL', 'Allemand'], ['ANG', 'Anglais'], ['ANT', 'Anthropologie'], ['ART', 'Arts et Archéologie'], ['ESP', 'Espagnol'], ['GEO', 'Géographie'], ['HIS', 'Histoire'], ['LAL', 'Langues Africaines et Linguistique'], ['BIL', 'Lettres Bilingues'], ['LCA', 'Littérature et Civilisation Africaine'], ['LMF', 'Lettres Modernes Françaises'], ['PHI', 'Philosophie'], ['PSY', 'Psychologie'], ['SDL', 'Sciences du Langage'], ['SOC', 'Sociologie'], ['TOU', 'Tourisme et Hôtellerie']]],
            'FSE' => ['Faculté des Sciences de l’Éducation', [['EFE', 'Enseignements Fondamentaux en Éducation'], ['MED', 'Management de l’Éducation'], ['DID', 'Didactique des Disciplines'], ['CEV', 'Curricula et Évaluations'], ['IOE', 'Intervention, Orientation et Éducation Extrascolaire'], ['EDS', 'Éducation Spécialisée']]],
            'FMSB' => ['Faculté de Médecine et des Sciences Biomédicales', []],
            'ENS' => ['École Normale Supérieure', [['ANG', 'Anglais'], ['BIO', 'Biologie'], ['CHI', 'Chimie'], ['FRA', 'Français'], ['GEO', 'Géographie'], ['HIS', 'Histoire'], ['INF', 'Informatique'], ['LCC', 'Langues et cultures camerounaises'], ['LET', 'Langues étrangères'], ['LCL', 'Lettres classiques'], ['MAT', 'Mathématiques'], ['PHI', 'Philosophie'], ['PHY', 'Physique'], ['SED', 'Sciences de l’éducation']]],
            'ENSPY' => ['École Nationale Supérieure Polytechnique de Yaoundé', [['MSP', 'Mathématiques et Sciences Physiques'], ['GC', 'Génie Civil et Urbain'], ['GET', 'Génie Électrique et des Télécommunications'], ['GI', 'Génie Informatique'], ['GIM', 'Génie Industriel et Mécanique'], ['MAI', 'Modélisation et Applications Industrielles'], ['MET', 'Météorologie'], ['EMI', 'Entrepreneuriat et Management de l’Innovation High-Tech']]],
            'IUT-BOIS' => ['Institut Universitaire de Technologie du Bois', []],
        ];
        foreach ($establishments as $code => [$name, $departments]) {
            $faculty = DB::table('gnu.faculte')->where('universite_id', $university)->where('code_fac', $code)->value('id');
            if ($faculty === null) {
                $faculty = DB::table('gnu.faculte')->insertGetId(['universite_id' => $university, 'code_fac' => $code, 'nom_fac' => $name]);
            }
            foreach ($departments as [$departmentCode, $departmentName]) {
                $exists = DB::table('gnu.departement')->where('faculte_id', $faculty)->where('code_de', $departmentCode)->exists();
                if (! $exists) {
                    DB::table('gnu.departement')->insert(['faculte_id' => $faculty, 'code_de' => $departmentCode, 'nom_depart' => $departmentName]);
                }
            }
        }
        // Filières documentées; les niveaux restent à configurer par l’établissement.
        $programs = [
            ['FALSH', 'ALL', 'ALL', 'Allemand'],
            ['FALSH', 'ANG', 'ANG', 'English'],
            ['FALSH', 'ESP', 'ESP', 'Espagnol'],
            ['FALSH', 'BIL', 'BIL', 'Lettres bilingues'],
            ['FALSH', 'LMF', 'LMF', 'Lettres modernes françaises'],
            ['FALSH', 'LCA', 'LCA', 'Littérature et civilisations africaines'],
            ['FALSH', 'ANT', 'ANT', 'Anthropologie'],
            ['FALSH', 'GEO', 'GEO', 'Géographie'],
            ['FALSH', 'HIS', 'HIS', 'Histoire'],
            ['FALSH', 'LAL', 'LAL', 'Langues africaines et linguistique'],
            ['FALSH', 'LAL', 'LGA', 'Linguistique générale et appliquée'],
            ['FALSH', 'PHI', 'PHI', 'Philosophie'],
            ['FALSH', 'PSY', 'PSY', 'Psychologie'],
            ['FALSH', 'SDL', 'SDL', 'Sciences du langage'],
            ['FALSH', 'SOC', 'SOC', 'Sociologie'],
            ['FALSH', 'ART', 'ASC', 'Arts du spectacle et cinématographie'],
            ['FALSH', 'ART', 'APH', 'Arts plastiques et histoire de l’art'],
            ['FALSH', 'ART', 'AGP', 'Archéologie et gestion du patrimoine'],
            ['FALSH', 'TOU', 'GT', 'Guide touristique'],
            ['FALSH', 'TOU', 'MET', 'Management des entreprises touristiques'],
        ];
        foreach ($establishments['FSE'][1] as [$code, $name]) {
            $programs[] = ['FSE', $code, $code, $name];
        }
        foreach ($programs as [$facultyCode, $departmentCode, $programCode, $programName]) {
            $department = DB::table('gnu.departement as d')->join('gnu.faculte as f', 'f.id', '=', 'd.faculte_id')
                ->where('f.universite_id', $university)->where('f.code_fac', $facultyCode)
                ->where('d.code_de', $departmentCode)->value('d.id');
            if (! DB::table('gnu.filiere')->where('departement_id', $department)->where('code_f', $programCode)->exists()) {
                DB::table('gnu.filiere')->insert(['departement_id' => $department, 'code_f' => $programCode, 'nom_f' => $programName]);
            }
        }
        $year = DB::table('gnu.annee_academique')->where('libelle', '2026-2027')->value('id');
        if ($year === null) {
            // Bornes techniques annuelles; le calendrier des examens reste configurable.
            $year = DB::table('gnu.annee_academique')->insertGetId(['libelle' => '2026-2027', 'date_debut' => '2026-10-01', 'date_fin' => '2027-09-30']);
        }
        // Reconduire les seules classes déjà configurées, sans déplacer l'historique.
        $classes = DB::table('gnu.classe as c')->join('gnu.annee_academique as a', 'a.id', '=', 'c.annee_id')
            ->orderByDesc('a.date_debut')->orderByDesc('c.id')->get(['c.*']);
        foreach ($classes->unique('niveau_id') as $class) {
            if (! DB::table('gnu.classe')->where('annee_id', $year)->where('niveau_id', $class->niveau_id)->exists()) {
                DB::table('gnu.classe')->insert([
                    'code_classe' => preg_replace('/(?:[-_](?:19|20)\d{2})(?:[-_](?:19|20)\d{2})?$/', '', $class->code_classe).'-2026-2027',
                    'niveau_id' => $class->niveau_id, 'annee_id' => $year,
                    'version_programme' => $class->version_programme, 'specialite_id' => $class->specialite_id,
                ]);
            }
        }
    }

    public function down(): void
    {
        throw new RuntimeException('Référentiel académique conservé : retour arrière à effectuer par restauration contrôlée.');
    }
};
