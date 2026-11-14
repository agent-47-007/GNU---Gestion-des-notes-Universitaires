<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use RuntimeException;

class Ict4dSiglUeDraftSeeder extends Seeder
{
    private const PROVISIONAL_CREDIT = 3.0;

    /** @var list<array{string, string, string, int}> */
    private const UNITS = [
        ['ENG103', 'ENGLISH I', 'L1', 1],
        ['FRA103', 'FRANÇAIS I', 'L1', 1],
        ['ICT101', 'INTRODUCTION TO BUSINESS INFORMATION SYSTEMS', 'L1', 1],
        ['ICT102', 'OBJECT-ORIENTED PROGRAMMING', 'L1', 2],
        ['ICT103', 'INTRODUCTION TO PROGRAMMING', 'L1', 1],
        ['ICT104', 'COMPUTER SYSTEMS', 'L1', 2],
        ['ICT105', 'INTRODUCTION TO ALGORITHMS', 'L1', 1],
        ['ICT106', 'DATA STRUCTURES AND PATTERNS I', 'L1', 2],
        ['ICT107', 'MATHEMATICS FOR COMPUTER SCIENCE I', 'L1', 1],
        ['ICT108', 'CREATING WEB APPLICATION', 'L1', 2],
        ['ICT109', 'DISCRETE MATHEMATICS I', 'L1', 1],
        ['ICT110', 'DATABASE ANALYSIS AND DESIGN', 'L1', 2],
        ['ICT111', 'DATA CODING', 'L1', 1],
        ['FRA203', 'FRANÇAIS II', 'L2', 1],
        ['ENG203', 'ENGLISH I', 'L2', 1],
        ['ICT201', 'INTRODUCTION TO SOFTWARE ENGINEERING', 'L2', 1],
        ['ICT202', 'SOFTWARE DEVELOPMENT FOR MOBILE DEVICES', 'L2', 2],
        ['ICT203', 'DATABASE SYSTEMS', 'L2', 1],
        ['ICT204', 'INTRODUCTION TO OPERATING SYSTEM', 'L2', 2],
        ['ICT205', 'INTRODUCTION TO PROGRAMMING IN .NET / PYTHON', 'L2', 1],
        ['ICT206', 'INTRODUCTION TO COMPUTER NETWORK', 'L2', 2],
        ['ICT207', 'SOFTWARE DEVELOPMENT IN JAVA I', 'L2', 1],
        ['ICT208', 'COMPUTER ARCHITECTURE', 'L2', 2],
        ['ICT210', 'DATABASE PROGRAMMING', 'L2', 2],
        ['ICT213', 'INTRODUCTION TO COMPUTER SECURITY AND RISK MANAGEMENT', 'L2', 1],
        ['ICT214', 'INTRODUCTION TO CRYPTOGRAPHY', 'L2', 2],
        ['ICT215', 'INTRODUCTION TO COMPUTER NETWORKING', 'L2', 1],
        ['ICT216', 'NETWORK ADMINISTRATION', 'L2', 2],
        ['ICT217', 'SOFTWARE ENGINEERING', 'L2', 1],
        ['ICT218', 'ADVANCED MOBILE APPLICATION DEVELOPMENT', 'L2', 2],
        ['ENG303', 'ENGLISH III', 'L3', 1],
        ['FRA303', 'FRANÇAIS III', 'L3', 1],
        ['ICT300', 'INTERNSHIP', 'L3', 2],
        ['ICT301', 'SOFTWARE ARCHITECTURES AND DESIGN', 'L3', 1],
        ['ICT302', 'INTRODUCTION TO ARTIFICIAL INTELLIGENCE', 'L3', 2],
        ['ICT303', 'DATA COMMUNICATION AND SECURITY', 'L3', 1],
        ['ICT304', 'SOFTWARE TESTING AND DEPLOYMENT', 'L3', 2],
        ['ICT305', 'WEB APPLICATION DEVELOPMENT', 'L3', 1],
        ['ICT306', 'BUSINESS INTELLIGENCE', 'L3', 2],
        ['ICT307', 'COMPUTER SYSTEMS ENGINEERING', 'L3', 1],
        ['ICT308', 'SOFTWARE DEVELOPMENT IN JAVA II', 'L3', 2],
        ['ICT310', 'PROFESSIONAL ISSUES IN IT', 'L3', 1],
        ['ICT313', 'CYBER AND INTERNET SECURITY', 'L3', 1],
        ['ICT314', 'COMPUTER FORENSICS AND INCIDENT RESPONSE', 'L3', 2],
        ['ICT315', 'NETWORK APPLICATION DEVELOPMENT', 'L3', 1],
        ['ICT316', 'DIGITAL COMMUNICATION', 'L3', 2],
        ['ICT317', 'INFORMATION SYSTEM', 'L3', 1],
        ['ICT318', 'JAVA ENTERPRISE EDITION', 'L3', 2],
        ['INF460', 'BASES DE DONNÉES', 'M1', 2],
        ['INF461', 'PRINCIPES ET PROCESSUS DU GÉNIE LOGICIEL', 'M1', 1],
        ['INF462', 'SPÉCIFICATION ET ARCHITECTURE DES LOGICIELS', 'M1', 2],
        ['INF463', 'PROGRAMMATION SOUS JAVA CMS', 'M1', 1],
        ['INF464', 'GESTION DES PROJETS', 'M1', 2],
        ['INF465', 'MODÉLISATION DES SYSTÈMES D’INFORMATION', 'M1', 1],
        ['INF466', 'SGBD ORACLE', 'M1', 2],
        ['INF467', 'URBANISATION ET ARCHITECTURE DE SYSTÈME D’INFORMATION', 'M1', 1],
        ['INF468', 'MODÉLISATION DES GRANDS VOLUMES DE DONNÉES / BIG DATA', 'M1', 2],
        ['INF469', 'PROGICIELS DE GESTION INTÉGRÉE / ERP', 'M1', 1],
        ['INF470', 'IT GOUVERNANCE - ALIGNEMENT STRATÉGIQUE ET GESTION', 'M1', 2],
        ['INF471', 'PRINCIPES ET PRATIQUE DES RÉSEAUX DE COMMUNICATION', 'M1', 1],
        ['INF560', 'STAGE EN ENTREPRISE ET SOUTENANCE DE MÉMOIRE', 'M2', 2],
        ['INF561', 'MODÉLISATION DES DONNÉES D’ENTREPRISE', 'M2', 1],
        ['INF562', 'SÉCURITÉ DES DONNÉES, AUDIT DES SYSTÈMES D’INFORMATION ET CYBERCRIMINALITÉ', 'M2', 2],
        ['INF563', 'VÉRIFICATION, VALIDATION DE LOGICIELS', 'M2', 1],
        ['INF564', 'INGÉNIERIE DES SYSTÈMES TEMPS RÉELS ET EMBARQUÉS', 'M2', 2],
        ['INF565', 'MODÉLISATION DES PROCESSUS MÉTIERS AU SEIN DES ORGANISATIONS', 'M2', 1],
        ['INF566', 'INFRASTRUCTURE TECHNOLOGIQUE DES SYSTÈMES D’INFORMATION', 'M2', 2],
    ];

    public function run(): void
    {
        DB::transaction(function (): void {
            DB::select('SELECT set_config(?, ?, true), set_config(?, ?, true)', [
                'gnu.acteur_id', '1',
                'gnu.motif', 'Ajout en brouillon des UE ICT4D et SIGL issues de la répartition 2026-2027',
            ]);

            $department = DB::table('gnu.departement')->where('code_de', 'INFO')->first(['id']);
            $ictTrack = DB::table('gnu.filiere')->where('departement_id', $department?->id)
                ->where('code_f', 'ICT')->first(['id']);
            $siglTrack = DB::table('gnu.filiere')->where('departement_id', $department?->id)
                ->where('code_f', 'SIGL')->first(['id']);
            if ($department === null || $ictTrack === null) {
                throw new RuntimeException('Le département INFO et la filière ICT doivent exister avant ce seeder.');
            }
            $siglTrackId = $siglTrack === null
                ? (int) DB::table('gnu.filiere')->insertGetId([
                    'departement_id' => $department->id,
                    'code_f' => 'SIGL',
                    'nom_f' => 'Système d’Information et Génie Logiciel',
                    'created_at' => now(),
                    'updated_at' => now(),
                ], 'id')
                : (int) $siglTrack->id;

            $levelIds = [];
            foreach ([
                ['ICT', (int) $ictTrack->id, 'L1', 'Licence 1', 'LICENCE'],
                ['ICT', (int) $ictTrack->id, 'L2', 'Licence 2', 'LICENCE'],
                ['ICT', (int) $ictTrack->id, 'L3', 'Licence 3', 'LICENCE'],
                ['SIGL', $siglTrackId, 'M1', 'Master 1', 'MASTER'],
                ['SIGL', $siglTrackId, 'M2', 'Master 2', 'MASTER'],
            ] as [$trackCode, $trackId, $code, $label, $cycle]) {
                $level = DB::table('gnu.niveau')->where('filiere_id', $trackId)
                    ->where('code_niv', $code)->first(['id']);
                $levelIds[$trackCode.':'.$code] = $level === null
                    ? (int) DB::table('gnu.niveau')->insertGetId([
                        'filiere_id' => $trackId,
                        'code_niv' => $code,
                        'libelle_niv' => $label,
                        'cycle_niv' => $cycle,
                        'created_at' => now(),
                        'updated_at' => now(),
                    ], 'id')
                    : (int) $level->id;
            }

            foreach (self::UNITS as [$code, $title, $level, $semester]) {
                $trackCode = in_array($level, ['M1', 'M2'], true) ? 'SIGL' : 'ICT';
                $levelId = $levelIds[$trackCode.':'.$level];
                $existing = DB::table('gnu.ue')->where('niveau_id', $levelId)
                    ->where('code_ue', $code)->first(['id', 'intitule_ue', 'numero_semestre', 'categorie_ue', 'credit_ue', 'statut_catalogue']);
                if ($existing !== null) {
                    if ($existing->intitule_ue !== $title || (int) $existing->numero_semestre !== $semester
                        || $existing->categorie_ue !== 'FONDAMENTALE'
                        || (float) $existing->credit_ue !== self::PROVISIONAL_CREDIT
                        || $existing->statut_catalogue !== 'BROUILLON') {
                        throw new RuntimeException("Le code UE {$code} existe déjà avec des données différentes.");
                    }

                    continue;
                }

                DB::table('gnu.ue')->insert([
                    'code_ue' => $code,
                    'intitule_ue' => $title,
                    'niveau_id' => $levelId,
                    'version_programme' => 1,
                    'numero_semestre' => $semester,
                    'categorie_ue' => 'FONDAMENTALE',
                    'credit_ue' => self::PROVISIONAL_CREDIT,
                    'statut_catalogue' => 'BROUILLON',
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);
            }
        });
    }
}
