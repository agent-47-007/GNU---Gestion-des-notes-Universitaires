<?php

namespace App\Console\Commands;

use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

#[Signature('gnu:generate-demo-grade-imports {--year=2025-2026 : Année académique à préparer} {--connection=pgsql : Connexion PostgreSQL} {--output=storage/app/imports/notes_fictives : Dossier de sortie relatif au backend}')]
#[Description('Génère des CSV de notes fictives à partir des classes, inscriptions et plans actifs d’une base de recette')]
class GenerateDemoGradeImports extends Command
{
    public function handle(): int
    {
        $connection = DB::connection((string) $this->option('connection'));
        $database = (string) $connection->getDatabaseName();
        if (preg_match('/(?:test|recette|dev)/i', $database) !== 1) {
            $this->components->error('Sécurité : les fichiers fictifs ne peuvent être générés que depuis une base nommée test, recette ou dev. Base sélectionnée : '.$database);

            return self::FAILURE;
        }

        $year = trim((string) $this->option('year'));
        $output = (string) $this->option('output');
        $outputDirectory = str_starts_with($output, DIRECTORY_SEPARATOR) ? $output : base_path($output);
        if (! is_dir($outputDirectory) && ! mkdir($outputDirectory, 0775, true) && ! is_dir($outputDirectory)) {
            $this->components->error('Impossible de créer le dossier de sortie : '.$outputDirectory);

            return self::FAILURE;
        }

        $assignments = $connection->table('gnu.affectation as a')
            ->join('gnu.classe as c', 'c.id', '=', 'a.classe_id')
            ->join('gnu.annee_academique as an', 'an.id', '=', 'c.annee_id')
            ->join('gnu.niveau as n', 'n.id', '=', 'c.niveau_id')
            ->join('gnu.matiere as m', 'm.id', '=', 'a.matiere_id')
            ->join('gnu.ue as ue', 'ue.id', '=', 'm.ue_id')
            ->where('an.libelle', $year)->where('a.actif', true)
            ->orderBy('c.code_classe')->orderBy('ue.code_ue')->orderBy('m.code_m')
            ->get([
                'a.id as affectation_id', 'a.classe_id', 'm.ue_id',
                'c.code_classe', 'n.code_niv', 'n.libelle_niv', 'an.libelle as annee',
                'ue.code_ue', 'm.code_m',
            ]);

        if ($assignments->isEmpty()) {
            $this->components->warn('Aucune affectation active trouvée pour '.$year.'. Aucun fichier n’a été créé.');

            return self::SUCCESS;
        }

        $created = 0;
        $skipped = [];
        foreach ($assignments as $assignment) {
            $evaluations = $connection->table('gnu.plan_evaluation as pe')
                ->join('gnu.ligne_plan as lp', 'lp.plan_id', '=', 'pe.id')
                ->join('gnu.evaluation as ev', 'ev.id', '=', 'lp.evaluation_id')
                ->where('pe.affectation_id', $assignment->affectation_id)
                ->where('pe.portee', 'CLASSE')->where('pe.statut_plan', 'ACTIF')->where('lp.retenue', true)
                ->whereIn('ev.type_eval', ['CC', 'TP', 'TPE', 'SN'])
                ->orderBy('ev.date_evaluation')->orderBy('ev.id')
                ->get(['ev.id', 'ev.type_eval']);
            $students = $connection->table('gnu.inscription_classe as ic')
                ->join('gnu.etudiant as e', 'e.id', '=', 'ic.etudiant_id')
                ->join('gnu.utilisateur as u', 'u.id', '=', 'e.utilisateur_id')
                ->join('gnu.inscription_ue as iu', function ($join) use ($assignment): void {
                    $join->on('iu.inscription_classe_id', '=', 'ic.id')->where('iu.ue_id', '=', $assignment->ue_id);
                })
                ->where('ic.classe_id', $assignment->classe_id)
                ->where('ic.statut_inscription', 'VALIDEE')->where('iu.statut_inscription', 'VALIDEE')
                ->orderBy('e.matricule')->get(['e.matricule', 'u.nom', 'u.prenom']);

            if ($evaluations->isEmpty() || $students->isEmpty()) {
                $skipped[] = $assignment->code_classe.' · '.$assignment->code_ue.' · '.$assignment->code_m
                    .' ('.($students->isEmpty() ? 'aucun étudiant inscrit' : 'aucun plan d’évaluation actif').')';

                continue;
            }

            $headers = ['Matricule', 'Nom', 'Prénom', 'Classe', 'Niveau', 'Année académique', 'UE', 'EC'];
            $occurrences = [];
            foreach ($evaluations as $evaluation) {
                $type = strtoupper((string) $evaluation->type_eval);
                $occurrences[$type] = ($occurrences[$type] ?? 0) + 1;
                $headers[] = $type.'_'.$occurrences[$type];
            }

            $filename = $this->filenamePart($assignment->code_classe.'-'.$assignment->code_ue.'-'.$assignment->code_m);
            $path = rtrim($outputDirectory, DIRECTORY_SEPARATOR).DIRECTORY_SEPARATOR.'FICTIF-NE-PAS-PUBLIER-'.$filename.'.csv';
            $handle = fopen($path, 'wb');
            if ($handle === false) {
                $this->components->error('Impossible d’écrire le fichier : '.$path);

                return self::FAILURE;
            }

            fputcsv($handle, $headers, ',', '"', '');
            foreach ($students as $student) {
                $row = [
                    (string) $student->matricule,
                    (string) $student->nom,
                    (string) $student->prenom,
                    (string) $assignment->code_classe,
                    (string) $assignment->code_niv.' · '.$assignment->libelle_niv,
                    (string) $assignment->annee,
                    (string) $assignment->code_ue,
                    (string) $assignment->code_m,
                ];
                foreach ($evaluations as $evaluation) {
                    $seed = crc32($student->matricule.'|'.$assignment->affectation_id.'|'.$evaluation->id);
                    $row[] = number_format((16 + ($seed % 25)) / 2, 1, '.', '');
                }
                fputcsv($handle, $row, ',', '"', '');
            }
            fclose($handle);
            $created++;
        }

        $this->table(['Base de lecture', 'Année', 'Fichiers créés', 'Affectations ignorées', 'Dossier'], [[
            $database, $year, $created, count($skipped), $outputDirectory,
        ]]);
        $this->components->info('Notes fictives générées entre 8 et 20. La commande n’insère ni ne modifie aucune donnée dans PostgreSQL. Importez ces CSV uniquement dans une base de recette pour tester le circuit complet.');
        foreach ($skipped as $item) {
            $this->line('• '.$item);
        }

        return self::SUCCESS;
    }

    private function filenamePart(string $value): string
    {
        $ascii = iconv('UTF-8', 'ASCII//TRANSLIT//IGNORE', $value);

        return trim(preg_replace('/[^A-Za-z0-9._-]+/', '-', (string) $ascii) ?? 'gnu', '-');
    }
}
