<?php

namespace App\Console\Commands;

use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;
use Illuminate\Database\Connection;
use Illuminate\Support\Facades\DB;

#[Signature('gnu:bootstrap-faculty-sciences-structure')]
#[Description('Initialise de façon idempotente les départements, filières et spécialités officiels de la Faculté des Sciences')]
class BootstrapFacultySciencesStructure extends Command
{
    /** @var array<string, array{department: string, department_name: string, program: string, program_name: string, options: list<array{0: string, 1: string}>}> */
    private const STRUCTURE = [
        'BIOC' => ['department' => 'BIOC', 'department_name' => 'Biochimie', 'program' => 'BIOC', 'program_name' => 'Biochimie', 'options' => [['BIOC-CLI', 'Biochimie clinique'], ['BIOC-PHA', 'Pharmacologie'], ['BIOC-TAN', 'Technologie alimentaire et nutrition']]],
        'MICR' => ['department' => 'MICR', 'department_name' => 'Microbiologie', 'program' => 'MICR', 'program_name' => 'Microbiologie', 'options' => [['MICR-MED', 'Microbiologie médicale'], ['MICR-IND', 'Microbiologie industrielle'], ['MICR-BIO', 'Biotechnologie']]],
        'BIOA' => ['department' => 'BIOA', 'department_name' => 'Biologie et Physiologie animales', 'program' => 'BIOA', 'program_name' => 'Biologie animale', 'options' => [['BIOA-ZOO', 'Zoologie'], ['BIOA-ECO', 'Écologie'], ['BIOA-PHY', 'Physiologie']]],
        'BIOV' => ['department' => 'BIOV', 'department_name' => 'Biologie et Physiologie végétales', 'program' => 'BIOV', 'program_name' => 'Biologie végétale', 'options' => [['BIOV-BOT', 'Botanique'], ['BIOV-PHY', 'Physiologie végétale'], ['BIOV-BIO', 'Biotechnologies végétales']]],
        'CHMO' => ['department' => 'CHMO', 'department_name' => 'Chimie organique', 'program' => 'CHMO', 'program_name' => 'Chimie organique', 'options' => []],
        'CHMI' => ['department' => 'CHMI', 'department_name' => 'Chimie inorganique', 'program' => 'CHMI', 'program_name' => 'Chimie inorganique', 'options' => [['CHMI-PHY', 'Chimie physique'], ['CHMI-MAT', 'Chimie des matériaux'], ['CHMI-ANA', 'Chimie analytique']]],
        'INFO' => ['department' => 'INFO', 'department_name' => 'Informatique', 'program' => 'INFO', 'program_name' => 'Informatique', 'options' => [['INFO-GL', 'Génie logiciel'], ['INFO-SR', 'Systèmes et réseaux'], ['INFO-SECU', 'Sécurité']]],
        'MATH' => ['department' => 'MATH', 'department_name' => 'Mathématiques', 'program' => 'MATH', 'program_name' => 'Mathématiques', 'options' => [['MATH-PUR', 'Mathématiques pures'], ['MATH-APP', 'Mathématiques appliquées']]],
        'PHYS' => ['department' => 'PHYS', 'department_name' => 'Physique', 'program' => 'PHYS', 'program_name' => 'Physique', 'options' => [['PHYS-ENR', 'Énergie renouvelable'], ['PHYS-ELE', 'Électronique'], ['PHYS-MEC', 'Mécanique'], ['PHYS-THE', 'Physique théorique']]],
        'STU' => ['department' => 'STU', 'department_name' => 'Sciences de la Terre et de l’Univers', 'program' => 'STU', 'program_name' => 'Sciences de la Terre', 'options' => [['STU-GEO', 'Géologie'], ['STU-GEH', 'Géotechnique et hydrogéologie'], ['STU-PET', 'Pétrologie'], ['STU-MIN', 'Minière']]],
    ];

    /** @var array<string, string> */
    private const DEPARTMENT_NAMES = [
        'BIOC' => 'Biochimie',
        'MICR' => 'Microbiologie',
        'BIOA' => 'Biologie et Physiologie animales',
        'BIOV' => 'Biologie et Physiologie végétales',
        'CHMO' => 'Chimie organique',
        'CHMI' => 'Chimie inorganique',
        'INFO' => 'Informatique',
        'MATH' => 'Mathématiques',
        'PHYS' => 'Physique',
        'STU' => 'Sciences de la Terre',
    ];

    /** @var list<array{0: string, 1: string}> */
    private const PLANNING_PROGRAMS = [
        ['BCH', 'Biochimie'], ['BIOS', 'Biosciences (L1-L2)'], ['BOA', 'Biologie animale'], ['BOV', 'Biologie végétale'],
        ['CHM', 'Chimie (intitulé général du planning)'], ['ENR', 'Énergies renouvelables (planning)'],
        ['GEOS', 'Géosciences (intitulé du planning)'], ['MIB', 'Microbiologie (planning)'], ['PHY', 'Physique (intitulé du planning)'],
    ];

    /** @var array<string, string> */
    private const PLANNING_DEPARTMENT_MAP = [
        'BCH' => 'BIOC', 'BOA' => 'BIOA', 'BOV' => 'BIOV', 'CHM' => 'CHMO / CHMI (intitulé planning à préciser)',
        'ENR' => 'PHYS', 'GEOS' => 'STU', 'MIB' => 'MICR', 'PHY' => 'PHYS',
    ];

    public function handle(): int
    {
        $database = (string) config('database.connections.pgsql_setup.database');
        if (! $this->confirm("Cette opération va initialiser la structure académique dans « {$database} ». Confirmez-vous la base cible ?")) {
            return self::FAILURE;
        }

        $connection = DB::connection('pgsql_setup');
        $tables = $connection->selectOne("SELECT to_regclass('gnu.universite') AS universite, to_regclass('gnu.faculte') AS faculte, to_regclass('gnu.departement') AS departement, to_regclass('gnu.filiere') AS filiere, to_regclass('gnu.specialite') AS specialite");
        if (collect((array) $tables)->contains(fn ($table): bool => empty($table))) {
            $this->components->error('Le schéma GNU doit déjà être installé, y compris les tables universite, faculte, departement, filiere et specialite. Cette commande ne lance aucune migration.');

            return self::FAILURE;
        }

        $counts = $connection->transaction(function () use ($connection): array {
            $connection->select("SELECT set_config('gnu.motif', ?, true)", ['Initialisation de la classification académique officielle de la Faculté des Sciences']);

            $universityId = $this->upsert($connection, 'universite', ['code_univ' => 'UY1'], ['nom_univ' => 'Université de Yaoundé I']);
            $facultyId = $this->upsert($connection, 'faculte', ['universite_id' => $universityId, 'code_fac' => 'FS'], ['nom_fac' => 'Faculté des Sciences']);
            $counts = ['departements' => 0, 'filieres' => 0, 'specialites' => 0];

            $departments = [];
            foreach (self::STRUCTURE as $entry) {
                $departmentCode = $entry['department'];
                if (! isset($departments[$departmentCode])) {
                    $departments[$departmentCode] = $this->upsert($connection, 'departement', ['faculte_id' => $facultyId, 'code_de' => $departmentCode], ['nom_depart' => self::DEPARTMENT_NAMES[$departmentCode]], $counts['departements']);
                }
                $departmentId = $departments[$departmentCode];
                $programId = $this->upsert($connection, 'filiere', ['departement_id' => $departmentId, 'code_f' => $entry['program']], ['nom_f' => $entry['program_name']], $counts['filieres']);

                foreach ($entry['options'] as [$code, $label]) {
                    $this->upsert($connection, 'specialite', ['filiere_id' => $programId, 'code_specialite' => $code], ['libelle_specialite' => $label, 'actif' => true], $counts['specialites']);
                }
            }

            return $counts;
        });

        $this->components->info("Structure de référence prête dans « {$database} » : ".count(self::DEPARTMENT_NAMES).' départements, '.count(self::STRUCTURE).' filières/mentions et '.array_sum(array_map(static fn (array $entry): int => count($entry['options']), self::STRUCTURE))." options configurés. Nouveaux enregistrements : {$counts['departements']} départements, {$counts['filieres']} filières, {$counts['specialites']} options.");
        $this->line('Correspondances des codes du planning vers les départements de la classification : '.collect(self::PLANNING_DEPARTMENT_MAP)->map(fn (string $department, string $program): string => $program.' → '.$department)->implode(', ').'.');

        return self::SUCCESS;
    }

    /** @param array<string, mixed> $keys
     * @param  array<string, mixed>  $values
     */
    private function upsert(Connection $connection, string $table, array $keys, array $values, ?int &$created = null): int
    {
        $query = $connection->table('gnu.'.$table);
        foreach ($keys as $key => $value) {
            $query->where($key, $value);
        }
        $row = $query->first(['id']);

        if ($row === null) {
            if ($created !== null) {
                $created++;
            }

            return (int) $connection->table('gnu.'.$table)->insertGetId($keys + $values + ['created_at' => now(), 'updated_at' => now()], 'id');
        }

        $connection->table('gnu.'.$table)->where('id', $row->id)->update($values + ['updated_at' => now()]);

        return (int) $row->id;
    }
}
