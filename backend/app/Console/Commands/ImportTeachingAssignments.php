<?php

namespace App\Console\Commands;

use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Throwable;

#[Signature('gnu:import-teaching-assignments {csv : Fichier CSV de correspondances enseignant/EC} {--year=2025-2026 : Année académique cible} {--actor=gnu-admin : Login de l’agent système qui trace l’import} {--apply : Appliquer les affectations fiables après confirmation}')]
#[Description('Importe les affectations pédagogiques fiables depuis une répartition de cours, avec audit et contrôle des collisions')]
class ImportTeachingAssignments extends Command
{
    private const TRUSTED_MATCHES = [
        'CODE_EC_ET_INTITULE_COHERENTS',
        'INTITULE_EC_EXACT',
        'INTITULE_EC_CORRESPONDANCE_FORTE',
    ];

    public function handle(): int
    {
        $path = (string) $this->argument('csv');
        if (! is_file($path) || ! is_readable($path)) {
            $this->components->error("Fichier CSV illisible : {$path}");

            return self::FAILURE;
        }

        $connection = DB::connection();
        $database = (string) $connection->getDatabaseName();
        $year = trim((string) $this->option('year'));
        $actorLogin = mb_strtolower(trim((string) $this->option('actor')));
        $actor = $connection->table('gnu.utilisateur')->whereRaw('lower(login) = ?', [$actorLogin])
            ->where('role', 'AGENT')->where('actif', true)->first(['id', 'login']);
        if ($actor === null || ! in_array($actorLogin, config('academic.publication_admin_logins', []), true)) {
            $this->components->error('L’acteur doit être un compte Agent actif déclaré dans GNU_PUBLICATION_ADMIN_LOGINS.');

            return self::FAILURE;
        }

        try {
            $rows = $this->readCsv($path, $year);
            $plan = $this->buildPlan($connection, $rows, $year);
        } catch (Throwable $error) {
            $this->components->error($error->getMessage());

            return self::FAILURE;
        }

        $teacherEids = array_values(array_unique(array_column([
            ...$plan['create'], ...$plan['reassign'], ...$plan['already'],
        ], 'eid')));
        $sourceEids = array_values(array_unique(array_filter(array_column($rows, 'enseignant_eid'))));
        $unassignedEids = array_values(array_diff($sourceEids, $teacherEids));
        $skippedCount = array_sum(array_map('count', $plan['skipped']));
        $this->table(['Base', 'Année', 'Lignes source', 'Enseignants concernés', 'À créer', 'À réaffecter', 'Déjà conformes', 'Ignorées'], [[
            $database, $year, count($rows), count($teacherEids), count($plan['create']), count($plan['reassign']), count($plan['already']), $skippedCount,
        ]]);
        if ($unassignedEids !== []) {
            $this->line('Enseignant(s) sans affectation fiable/compatible : '.implode(', ', $unassignedEids));
        }
        foreach ($plan['skipped'] as $reason => $items) {
            $this->line("• {$reason} : ".count($items));
            foreach (array_slice($items, 0, 3) as $item) {
                $this->line('  '.$item);
            }
        }

        if (! $this->option('apply')) {
            $this->components->info('Prévisualisation uniquement. Aucun changement effectué. Ajoutez --apply après vérification.');

            return self::SUCCESS;
        }
        if (! $this->confirm("Créer/réaffecter les lignes fiables dans « {$database} » pour {$year} ?")) {
            return self::SUCCESS;
        }

        $reason = "Import des affectations selon la répartition officielle {$year}; correspondances fiables du CSV.";
        try {
            $connection->transaction(function () use ($connection, $actor, $reason, $plan): void {
                $connection->select("SELECT set_config('gnu.acteur_id', ?, true), set_config('gnu.motif', ?, true)", [(string) $actor->id, $reason]);

                foreach ($plan['create'] as $item) {
                    $connection->table('gnu.affectation')->insert([
                        'enseignant_id' => $item['enseignant_id'],
                        'matiere_id' => $item['matiere_id'],
                        'classe_id' => $item['classe_id'],
                        'actif' => true,
                        'created_at' => now(),
                        'updated_at' => now(),
                    ]);
                }
                foreach ($plan['reassign'] as $item) {
                    $connection->table('gnu.affectation')->where('id', $item['affectation_id'])->update([
                        'actif' => false,
                        'updated_at' => now(),
                    ]);
                    $connection->table('gnu.affectation')->insert([
                        'enseignant_id' => $item['enseignant_id'],
                        'matiere_id' => $item['matiere_id'],
                        'classe_id' => $item['classe_id'],
                        'actif' => true,
                        'created_at' => now(),
                        'updated_at' => now(),
                    ]);
                }
            });
        } catch (Throwable $error) {
            report($error);
            $this->components->error('Import annulé : aucune affectation de cette opération n’a été conservée. Consultez le journal Laravel.');

            return self::FAILURE;
        }

        $this->components->info((count($plan['create']) + count($plan['reassign'])).' affectation(s) active(s) créée(s). Les anciennes affectations remplacées sont conservées désactivées avec leur historique.');
        $this->components->warn('Les correspondances ignorées restent à corriger dans le catalogue/la structure ou à confirmer avant affectation.');

        return self::SUCCESS;
    }

    /** @return list<array<string, string>> */
    private function readCsv(string $path, string $year): array
    {
        $handle = fopen($path, 'rb');
        if ($handle === false) {
            throw new \RuntimeException('Impossible d’ouvrir le CSV.');
        }
        try {
            $headers = fgetcsv($handle);
            if ($headers === false) {
                throw new \RuntimeException('Le CSV est vide.');
            }
            $headers[0] = preg_replace('/^\xEF\xBB\xBF/', '', (string) $headers[0]);
            $headers = array_map(static fn ($value): string => trim((string) $value), $headers);
            $required = ['annee_academique', 'niveau', 'enseignant_eid', 'code_ec_gnu', 'intitule_ec_gnu', 'statut_correspondance'];
            $missing = array_diff($required, $headers);
            if ($missing !== []) {
                throw new \RuntimeException('Colonnes CSV manquantes : '.implode(', ', $missing));
            }
            $rows = [];
            while (($values = fgetcsv($handle)) !== false) {
                if (count($values) === 1 && trim((string) $values[0]) === '') {
                    continue;
                }
                $row = array_combine($headers, array_pad($values, count($headers), ''));
                if (($row['annee_academique'] ?? '') === $year) {
                    $rows[] = array_map(static fn ($value): string => trim((string) $value), $row);
                }
            }

            return $rows;
        } finally {
            fclose($handle);
        }
    }

    /** @param list<array<string, string>> $rows
     * @return array{create:list<array<string,int>>,reassign:list<array<string,int>>,already:list<array<string,int>>,skipped:array<string,list<string>>}
     */
    private function buildPlan(mixed $connection, array $rows, string $year): array
    {
        $plan = ['create' => [], 'reassign' => [], 'already' => [], 'skipped' => []];
        $candidates = [];
        foreach ($rows as $row) {
            if (! in_array($row['statut_correspondance'], self::TRUSTED_MATCHES, true)) {
                $this->skip($plan, 'Correspondance à confirmer ou non exploitable', $row);

                continue;
            }
            if ($row['code_ec_gnu'] === '') {
                $this->skip($plan, 'EC cible non défini', $row);

                continue;
            }

            $classes = $connection->table('gnu.classe as c')
                ->join('gnu.annee_academique as an', 'an.id', '=', 'c.annee_id')
                ->join('gnu.niveau as n', 'n.id', '=', 'c.niveau_id')
                ->where('an.libelle', $year)->where('n.code_niv', $row['niveau'])
                ->whereNull('c.specialite_id')->get(['c.id', 'c.niveau_id', 'c.code_classe']);
            if ($classes->count() !== 1) {
                $this->skip($plan, $classes->isEmpty() ? 'Classe générale du niveau absente' : 'Plusieurs classes générales pour le niveau', $row);

                continue;
            }
            $class = $classes->first();

            $teacher = $connection->table('gnu.enseignant as e')
                ->join('gnu.utilisateur as u', 'u.id', '=', 'e.utilisateur_id')
                ->whereRaw('upper(e.eid) = ?', [mb_strtoupper($row['enseignant_eid'])])
                ->where('u.role', 'ENSEIGNANT')->where('u.actif', true)
                ->first(['e.id', 'e.eid']);
            if ($teacher === null) {
                $this->skip($plan, 'Compte enseignant absent/inactif', $row);

                continue;
            }

            $courses = $connection->table('gnu.matiere as m')->join('gnu.ue as ue', 'ue.id', '=', 'm.ue_id')
                ->where('ue.niveau_id', $class->niveau_id)
                ->where('ue.statut_catalogue', 'ACTIF')->where('m.code_m', $row['code_ec_gnu'])
                ->get(['m.id', 'm.code_m']);
            if ($courses->isEmpty() && $row['intitule_ec_gnu'] !== '') {
                $courses = $connection->table('gnu.matiere as m')->join('gnu.ue as ue', 'ue.id', '=', 'm.ue_id')
                    ->where('ue.niveau_id', $class->niveau_id)
                    ->where('ue.statut_catalogue', 'ACTIF')
                    ->whereRaw('lower(trim(m.intitule_matiere)) = lower(trim(?))', [$row['intitule_ec_gnu']])
                    ->get(['m.id', 'm.code_m']);
            }
            if ($courses->count() !== 1) {
                $this->skip($plan, $courses->isEmpty() ? 'EC absent du catalogue actif de la classe' : 'EC cible ambigu dans le catalogue', $row);

                continue;
            }

            $key = $class->id.':'.$courses[0]->id;
            $candidates[$key][] = [
                'classe_id' => (int) $class->id,
                'matiere_id' => (int) $courses[0]->id,
                'enseignant_id' => (int) $teacher->id,
                'eid' => (string) $teacher->eid,
                'code_classe' => (string) $class->code_classe,
                'code_m' => (string) $courses[0]->code_m,
            ];
        }

        foreach ($candidates as $items) {
            $teacherIds = array_unique(array_column($items, 'enseignant_id'));
            if (count($teacherIds) !== 1) {
                $plan['skipped']['Plusieurs enseignants proposés pour le même EC/classe'][] = $items[0]['code_classe'].' · '.$items[0]['code_m'];

                continue;
            }
            $candidate = $items[0];
            $existing = $connection->table('gnu.affectation')->where('classe_id', $candidate['classe_id'])
                ->where('matiere_id', $candidate['matiere_id'])->where('actif', true)->first(['id', 'enseignant_id']);
            if ($existing === null) {
                $plan['create'][] = $candidate;

                continue;
            }
            if ((int) $existing->enseignant_id === $candidate['enseignant_id']) {
                $plan['already'][] = $candidate;

                continue;
            }

            $hasPendingProposal = $connection->table('gnu.proposition_affectation_enseignant')
                ->where('affectation_id', $existing->id)->where('statut', 'EN_ATTENTE')->exists();
            $hasGrades = $connection->table('gnu.note as note')->join('gnu.evaluation as ev', 'ev.id', '=', 'note.evaluation_id')
                ->where('ev.affectation_id', $existing->id)->exists();
            $hasTransmission = $connection->table('gnu.transmission_note')->where('affectation_id', $existing->id)->exists();
            if ($hasPendingProposal || $hasGrades || $hasTransmission) {
                $this->skip($plan, 'Affectation existante avec demande/notes/transmission : réaffectation protégée', $candidate);

                continue;
            }
            $plan['reassign'][] = [...$candidate, 'affectation_id' => (int) $existing->id];
        }

        return $plan;
    }

    /** @param array<string,mixed> $row */
    private function skip(array &$plan, string $reason, array $row): void
    {
        $plan['skipped'][$reason][] = trim(($row['niveau'] ?? '').' · '.($row['code_ec_gnu'] ?? '').' · '.($row['enseignant_eid'] ?? ''));
    }
}
