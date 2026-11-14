<?php

namespace App\Console\Commands;

use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;
use Illuminate\Database\Connection;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use RuntimeException;
use Throwable;

#[Signature('gnu:import-informatics-catalogue {--apply : Importer les niveaux, UE et EC dans gnu_notes_sgbd après aperçu}')]
#[Description('Copie le catalogue du département Informatique de gnu_notes vers gnu_notes_sgbd, sans comptes ni données étudiantes')]
class ImportInformaticsCatalogue extends Command
{
    public function handle(): int
    {
        $source = DB::connection('pgsql_source');
        $target = DB::connection('pgsql_setup');
        $sourceName = (string) $source->getDatabaseName();
        $targetName = (string) $target->getDatabaseName();

        if ($sourceName !== 'gnu_notes' || $targetName !== 'gnu_notes_sgbd') {
            $this->components->error("Cibles inattendues : source « {$sourceName} », cible « {$targetName} ». La commande exige gnu_notes → gnu_notes_sgbd.");

            return self::FAILURE;
        }

        try {
            $sourceLevels = $this->sourceLevels($source);
            if ($sourceLevels->isEmpty()) {
                $this->components->warn('Aucun niveau Informatique trouvé dans gnu_notes. Vérifiez le code INFO du département source.');

                return self::SUCCESS;
            }

            $sourceUnits = $source->table('gnu.ue as u')
                ->join('gnu.niveau as n', 'n.id', '=', 'u.niveau_id')
                ->join('gnu.filiere as f', 'f.id', '=', 'n.filiere_id')
                ->join('gnu.departement as d', 'd.id', '=', 'f.departement_id')
                ->whereRaw('upper(d.code_de) = ?', ['INFO'])
                ->whereRaw('upper(f.code_f) = ?', ['INF'])
                ->whereRaw('u.version_programme = (SELECT MAX(u2.version_programme) FROM gnu.ue u2 WHERE u2.niveau_id = u.niveau_id)')
                ->orderBy('n.code_niv')->orderBy('u.code_ue')
                ->get([
                    'u.id as source_id', 'u.code_ue', 'u.intitule_ue', 'n.id as source_niveau_id',
                    'n.code_niv', 'f.id as source_filiere_id', 'f.code_f', 'f.nom_f',
                    'u.version_programme', 'u.numero_semestre', 'u.categorie_ue', 'u.credit_ue',
                    'u.statut_catalogue', 'u.created_at', 'u.updated_at',
                ]);
            $sourceMatterCounts = $source->table('gnu.matiere as m')
                ->join('gnu.ue as u', 'u.id', '=', 'm.ue_id')
                ->join('gnu.niveau as n', 'n.id', '=', 'u.niveau_id')
                ->join('gnu.filiere as f', 'f.id', '=', 'n.filiere_id')
                ->join('gnu.departement as d', 'd.id', '=', 'f.departement_id')
                ->whereRaw('upper(d.code_de) = ?', ['INFO'])
                ->whereRaw('upper(f.code_f) = ?', ['INF'])
                ->whereRaw('u.version_programme = (SELECT MAX(u2.version_programme) FROM gnu.ue u2 WHERE u2.niveau_id = u.niveau_id)')
                ->count();

            $this->table(['Source', 'Cible', 'Niveaux', 'UE', 'EC (matières)'], [[
                $sourceName, $targetName, $sourceLevels->count(), $sourceUnits->count(), $sourceMatterCounts,
            ]]);
            $this->line('Seuls le cursus Informatique (filière INF), sa dernière version par niveau, et ses UE/EC sans doublons seront copiés. Aucune filière ICT4D, ancienne version de programme, compte, classe, étudiant, inscription, note, affectation ou PV ne sera importé.');

            if (! $this->option('apply')) {
                $this->components->info('Aperçu uniquement : aucune donnée modifiée. Relancez avec --apply après vérification.');

                return self::SUCCESS;
            }

            if (! $this->confirm("Copier le catalogue Informatique de « {$sourceName} » vers « {$targetName} » ?")) {
                return self::SUCCESS;
            }

            $result = $target->transaction(function () use ($source, $target, $sourceLevels, $sourceUnits): array {
                $target->select("SELECT set_config('gnu.motif', ?, true)", ['Import contrôlé du catalogue Informatique depuis gnu_notes pour recette dans gnu_notes_sgbd']);
                $department = $target->table('gnu.departement')->where('code_de', 'INFO')->first(['id']);
                if ($department === null) {
                    throw new RuntimeException('Le département INFO est absent de la base cible; initialisez la structure académique avant l’import.');
                }

                $filiereMap = [];
                $levelMap = [];
                $unitMap = [];
                $counts = ['filieres' => 0, 'specialites' => 0, 'niveaux' => 0, 'ue' => 0, 'ec' => 0, 'existing' => 0, 'ue_ec_doublons_supprimes' => 0];

                foreach ($sourceLevels as $level) {
                    if (! isset($filiereMap[$level->source_filiere_id])) {
                        $targetProgram = $target->table('gnu.filiere')
                            ->where('departement_id', $department->id)
                            ->whereRaw('lower(nom_f) = lower(?)', [$level->nom_f])
                            ->first(['id']);
                        if ($targetProgram === null) {
                            $targetPrograms = $target->table('gnu.filiere')->where('departement_id', $department->id)->get(['id']);
                            if ($targetPrograms->count() === 1) {
                                $targetProgram = $targetPrograms->first();
                            } else {
                                $targetProgram = $target->table('gnu.filiere')->where('departement_id', $department->id)
                                    ->where('code_f', $level->code_f)->first(['id']);
                            }
                        }
                        if ($targetProgram === null) {
                            $filiereId = (int) $target->table('gnu.filiere')->insertGetId([
                                'departement_id' => $department->id,
                                'code_f' => $level->code_f,
                                'nom_f' => $level->nom_f,
                                'created_at' => now(), 'updated_at' => now(),
                            ], 'id');
                            $counts['filieres']++;
                        } else {
                            $filiereId = (int) $targetProgram->id;
                        }
                        $filiereMap[$level->source_filiere_id] = $filiereId;
                    }

                    $specialiteId = null;
                    if ($level->source_specialite_id !== null) {
                        $specialite = $target->table('gnu.specialite')
                            ->where('filiere_id', $filiereMap[$level->source_filiere_id])
                            ->where(function ($query) use ($level): void {
                                $query->whereRaw('upper(code_specialite) = upper(?)', [$level->source_specialite_code])
                                    ->orWhereRaw("upper(split_part(code_specialite, '-', array_length(string_to_array(code_specialite, '-'), 1))) = upper(?)", [$level->source_specialite_code])
                                    ->orWhereRaw('lower(libelle_specialite) = lower(?)', [$level->source_specialite_name]);
                            })->first(['id']);
                        if ($specialite === null) {
                            $specialiteId = (int) $target->table('gnu.specialite')->insertGetId([
                                'code_specialite' => $level->source_specialite_code,
                                'libelle_specialite' => $level->source_specialite_name,
                                'filiere_id' => $filiereMap[$level->source_filiere_id],
                                'actif' => true,
                                'created_at' => now(), 'updated_at' => now(),
                            ], 'id');
                            $counts['specialites']++;
                        } else {
                            $specialiteId = (int) $specialite->id;
                        }
                    }

                    $targetLevel = $target->table('gnu.niveau')
                        ->where('filiere_id', $filiereMap[$level->source_filiere_id])
                        ->where('code_niv', $level->code_niv)->first(['id']);
                    if ($targetLevel === null) {
                        $levelId = (int) $target->table('gnu.niveau')->insertGetId([
                            'code_niv' => $level->code_niv,
                            'cycle_niv' => $level->cycle_niv,
                            'libelle_niv' => $level->libelle_niv,
                            'filiere_id' => $filiereMap[$level->source_filiere_id],
                            'specialite_id' => $specialiteId,
                            'created_at' => now(), 'updated_at' => now(),
                        ], 'id');
                        $counts['niveaux']++;
                    } else {
                        $levelId = (int) $targetLevel->id;
                    }
                    $levelMap[$level->source_niveau_id] = $levelId;
                }

                $counts['ue_ec_doublons_supprimes'] = $this->canonicalizeTargetCatalogue($source, $target, $sourceUnits, $levelMap);

                $duplicateSourceUnits = $sourceUnits->groupBy(fn ($unit): string => ($levelMap[$unit->source_niveau_id] ?? 'missing').'|'.$unit->code_ue)
                    ->filter(fn (Collection $units): bool => $units->count() > 1);
                if ($duplicateSourceUnits->isNotEmpty()) {
                    $duplicateCodes = $duplicateSourceUnits->map(fn (Collection $units): string => (string) $units->first()->code_ue)->implode(', ');
                    throw new RuntimeException('Le programme INF source contient des codes UE dupliqués après rapprochement des niveaux : '.$duplicateCodes.'.');
                }

                $targetVersions = [];
                foreach ($sourceUnits->groupBy(fn ($unit): string => ($levelMap[$unit->source_niveau_id] ?? 'missing').'|'.$unit->version_programme) as $groupKey => $units) {
                    $first = $units->first();
                    $levelId = $levelMap[$first->source_niveau_id] ?? null;
                    if ($levelId === null) {
                        throw new RuntimeException("Niveau cible introuvable pour la version {$first->version_programme}.");
                    }
                    foreach ($units as $unit) {
                        $existing = $target->table('gnu.ue')->where('niveau_id', $levelId)
                            ->where('version_programme', 1)->where('code_ue', $unit->code_ue)
                            ->first(['id', 'intitule_ue', 'numero_semestre', 'categorie_ue', 'credit_ue', 'statut_catalogue']);
                        if ($existing === null) {
                            continue;
                        }
                        if ($existing->intitule_ue !== $unit->intitule_ue
                            || (int) $existing->numero_semestre !== (int) $unit->numero_semestre
                            || $existing->categorie_ue !== $unit->categorie_ue
                            || (float) $existing->credit_ue !== (float) $unit->credit_ue) {
                            throw new RuntimeException("L’UE {$unit->code_ue} existe déjà avec un contenu différent en cible; aucune nouvelle version ne sera créée.");
                        }
                        $sourceMatters = $source->table('gnu.matiere')->where('ue_id', $unit->source_id)->orderBy('rang_ec')
                            ->get(['code_m', 'intitule_matiere', 'rang_ec', 'credit_matiere']);
                        $targetMatters = $target->table('gnu.matiere')->where('ue_id', $existing->id)->orderBy('rang_ec')
                            ->get(['code_m', 'intitule_matiere', 'rang_ec', 'credit_matiere']);
                        if ($sourceMatters->count() !== $targetMatters->count()) {
                            if ($existing->statut_catalogue !== 'BROUILLON' || $targetMatters->isNotEmpty()) {
                                throw new RuntimeException("L’UE {$unit->code_ue} existe déjà avec une liste d’EC différente en cible.");
                            }
                        } else {
                            foreach ($sourceMatters as $index => $matter) {
                                $targetMatter = $targetMatters[$index];
                                if ($matter->code_m !== $targetMatter->code_m
                                    || $matter->intitule_matiere !== $targetMatter->intitule_matiere
                                    || (int) $matter->rang_ec !== (int) $targetMatter->rang_ec
                                    || (float) $matter->credit_matiere !== (float) $targetMatter->credit_matiere) {
                                    throw new RuntimeException("L’UE {$unit->code_ue} possède des EC différents en cible; aucune version supplémentaire ne sera créée.");
                                }
                            }
                        }
                    }
                    $targetVersions[$groupKey] = 1;
                }

                foreach ($sourceUnits as $unit) {
                    $levelId = $levelMap[$unit->source_niveau_id] ?? null;
                    if ($levelId === null) {
                        throw new RuntimeException("Niveau cible introuvable pour l’UE {$unit->code_ue}.");
                    }
                    $versionKey = $levelId.'|'.$unit->version_programme;
                    $targetVersion = $targetVersions[$versionKey] ?? (int) $unit->version_programme;
                    $existing = $target->table('gnu.ue')->where('niveau_id', $levelId)
                        ->where('version_programme', $targetVersion)->where('code_ue', $unit->code_ue)
                        ->first(['id', 'intitule_ue', 'numero_semestre', 'categorie_ue', 'credit_ue', 'statut_catalogue']);
                    if ($existing === null) {
                        $unitId = (int) $target->table('gnu.ue')->insertGetId([
                            'code_ue' => $unit->code_ue,
                            'intitule_ue' => $unit->intitule_ue,
                            'niveau_id' => $levelId,
                            'version_programme' => $targetVersion,
                            'numero_semestre' => $unit->numero_semestre,
                            'categorie_ue' => $unit->categorie_ue,
                            'credit_ue' => $unit->credit_ue,
                            'statut_catalogue' => 'BROUILLON',
                            'created_at' => now(), 'updated_at' => now(),
                        ], 'id');
                        $counts['ue']++;
                    } else {
                        $unitId = (int) $existing->id;
                        $same = $existing->intitule_ue === $unit->intitule_ue
                            && (int) $existing->numero_semestre === (int) $unit->numero_semestre
                            && $existing->categorie_ue === $unit->categorie_ue
                            && (float) $existing->credit_ue === (float) $unit->credit_ue;
                        if (! $same && $existing->statut_catalogue !== 'BROUILLON') {
                            throw new RuntimeException("L’UE {$unit->code_ue} existe déjà avec un contenu différent et n’est pas modifiable (statut {$existing->statut_catalogue}).");
                        }
                        if (! $same) {
                            $target->table('gnu.ue')->where('id', $unitId)->update([
                                'intitule_ue' => $unit->intitule_ue,
                                'numero_semestre' => $unit->numero_semestre,
                                'categorie_ue' => $unit->categorie_ue,
                                'credit_ue' => $unit->credit_ue,
                                'updated_at' => now(),
                            ]);
                        } else {
                            $counts['existing']++;
                        }
                    }
                    $unitMap[$unit->source_id] = ['id' => $unitId, 'source_status' => $unit->statut_catalogue];

                    $sourceMatters = $source->table('gnu.matiere')->where('ue_id', $unit->source_id)->orderBy('rang_ec')->get(['code_m', 'intitule_matiere', 'rang_ec', 'credit_matiere']);
                    foreach ($sourceMatters as $matter) {
                        $targetMatter = $target->table('gnu.matiere')->where('ue_id', $unitId)
                            ->where(function ($query) use ($matter): void {
                                $query->where('code_m', $matter->code_m);
                            })->first(['id', 'code_m', 'intitule_matiere', 'rang_ec', 'credit_matiere']);
                        if ($targetMatter === null) {
                            $target->table('gnu.matiere')->insert([
                                'code_m' => $matter->code_m,
                                'intitule_matiere' => $matter->intitule_matiere,
                                'ue_id' => $unitId,
                                'rang_ec' => $matter->rang_ec,
                                'credit_matiere' => $matter->credit_matiere,
                                'created_at' => now(), 'updated_at' => now(),
                            ]);
                            $counts['ec']++;
                        } elseif ($targetMatter->code_m !== $matter->code_m
                            || $targetMatter->intitule_matiere !== $matter->intitule_matiere
                            || (int) $targetMatter->rang_ec !== (int) $matter->rang_ec
                            || (float) $targetMatter->credit_matiere !== (float) $matter->credit_matiere) {
                            throw new RuntimeException("L’EC {$matter->code_m} de l’UE {$unit->code_ue} existe déjà avec des données différentes.");
                        }
                    }
                }

                foreach ($unitMap as $unit) {
                    if ($unit['source_status'] === 'ACTIF') {
                        $matterCount = $target->table('gnu.matiere')->where('ue_id', $unit['id'])->count();
                        if ($matterCount >= 1 && $matterCount <= 2) {
                            $target->table('gnu.ue')->where('id', $unit['id'])->update(['statut_catalogue' => 'ACTIF', 'updated_at' => now()]);
                        }
                    } elseif ($unit['source_status'] === 'ARCHIVE') {
                        $target->table('gnu.ue')->where('id', $unit['id'])->where('statut_catalogue', 'BROUILLON')->update(['statut_catalogue' => 'ARCHIVE', 'updated_at' => now()]);
                    }
                }

                return $counts;
            });

            $this->components->info("Catalogue Informatique importé dans « {$targetName} » : ".json_encode($result, JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR));
            $this->line('Les UE sans EC héritent du statut BROUILLON si les règles GNU empêchent leur activation dans cette structure.');

            return self::SUCCESS;
        } catch (Throwable $error) {
            $this->components->error('Import annulé : '.$error->getMessage());

            return self::FAILURE;
        }
    }

    private function canonicalizeTargetCatalogue(Connection $source, Connection $target, Collection $sourceUnits, array $levelMap): int
    {
        $expected = [];
        foreach ($sourceUnits as $unit) {
            $levelId = $levelMap[$unit->source_niveau_id] ?? null;
            if ($levelId !== null) {
                $expected[$levelId.'|'.$unit->code_ue] = $unit;
            }
        }

        $targetUnits = $target->table('gnu.ue')->whereIn('niveau_id', array_values($levelMap))
            ->orderBy('niveau_id')->orderBy('code_ue')->orderBy('version_programme')
            ->get(['id', 'niveau_id', 'code_ue', 'version_programme', 'intitule_ue', 'numero_semestre', 'categorie_ue', 'credit_ue']);
        $deleteIds = [];
        $keptKeys = [];
        foreach ($targetUnits as $targetUnit) {
            $key = $targetUnit->niveau_id.'|'.$targetUnit->code_ue;
            $sourceUnit = $expected[$key] ?? null;
            if ($sourceUnit === null || (int) $targetUnit->version_programme !== 1 || isset($keptKeys[$key])) {
                $deleteIds[] = (int) $targetUnit->id;

                continue;
            }

            $sameUnit = $targetUnit->intitule_ue === $sourceUnit->intitule_ue
                && (int) $targetUnit->numero_semestre === (int) $sourceUnit->numero_semestre
                && $targetUnit->categorie_ue === $sourceUnit->categorie_ue
                && (float) $targetUnit->credit_ue === (float) $sourceUnit->credit_ue;
            if ($sameUnit && $this->sameUnitElements($source, $target, (int) $sourceUnit->source_id, (int) $targetUnit->id)) {
                $keptKeys[$key] = true;
            } else {
                $deleteIds[] = (int) $targetUnit->id;
            }
        }

        $deleteIds = array_values(array_unique($deleteIds));
        if ($deleteIds === []) {
            return 0;
        }

        $removedUnits = $targetUnits->whereIn('id', $deleteIds);
        foreach ($removedUnits->groupBy(fn (object $unit): string => $unit->niveau_id.'|'.$unit->version_programme) as $versionGroup) {
            $first = $versionGroup->first();
            if ($target->table('gnu.classe')->where('niveau_id', $first->niveau_id)
                ->where('version_programme', $first->version_programme)->exists()) {
                throw new RuntimeException('Des classes utilisent encore une ancienne version du programme Informatique. Les doublons ne sont pas supprimés pour protéger leurs inscriptions et leurs notes.');
            }
        }

        foreach ([
            'inscription_ue' => 'ue_id',
            'profil_evaluation_ue' => 'ue_id',
            'proposition_profil_evaluation' => 'ue_id',
            'session_rattrapage_ue' => 'ue_id',
            'responsable_note_ue' => 'ue_id',
        ] as $table => $column) {
            if ($this->relationExists($target, 'gnu.'.$table)
                && $target->table('gnu.'.$table)->whereIn($column, $deleteIds)->exists()) {
                throw new RuntimeException('Des données académiques utilisent déjà les UE Informatique à dédupliquer. Elles sont conservées; aucune ligne n’a été supprimée.');
            }
        }

        $matterIds = $target->table('gnu.matiere')->whereIn('ue_id', $deleteIds)->pluck('id')->all();
        if ($matterIds !== []) {
            foreach (['affectation' => 'matiere_id', 'requete' => 'matiere_id'] as $table => $column) {
                if ($this->relationExists($target, 'gnu.'.$table)
                    && $target->table('gnu.'.$table)->whereIn($column, $matterIds)->exists()) {
                    throw new RuntimeException('Des affectations ou requêtes référencent les EC à dédupliquer. Elles sont conservées; aucune ligne n’a été supprimée.');
                }
            }
            $target->table('gnu.matiere')->whereIn('ue_id', $deleteIds)->delete();
        }
        $target->table('gnu.ue')->whereIn('id', $deleteIds)->delete();

        return count($deleteIds);
    }

    private function sameUnitElements(Connection $source, Connection $target, int $sourceUnitId, int $targetUnitId): bool
    {
        $sourceElements = $source->table('gnu.matiere')->where('ue_id', $sourceUnitId)->orderBy('rang_ec')
            ->get(['code_m', 'intitule_matiere', 'rang_ec', 'credit_matiere']);
        $targetElements = $target->table('gnu.matiere')->where('ue_id', $targetUnitId)->orderBy('rang_ec')
            ->get(['code_m', 'intitule_matiere', 'rang_ec', 'credit_matiere']);
        if ($sourceElements->count() !== $targetElements->count()) {
            return false;
        }
        foreach ($sourceElements as $index => $element) {
            $existing = $targetElements[$index];
            if ($element->code_m !== $existing->code_m
                || $element->intitule_matiere !== $existing->intitule_matiere
                || (int) $element->rang_ec !== (int) $existing->rang_ec
                || (float) $element->credit_matiere !== (float) $existing->credit_matiere) {
                return false;
            }
        }

        return true;
    }

    private function relationExists(Connection $connection, string $relation): bool
    {
        return $connection->selectOne('SELECT to_regclass(?) IS NOT NULL AS present', [$relation])->present;
    }

    private function sourceLevels(Connection $source): Collection
    {
        return $source->table('gnu.niveau as n')
            ->join('gnu.filiere as f', 'f.id', '=', 'n.filiere_id')
            ->join('gnu.departement as d', 'd.id', '=', 'f.departement_id')
            ->leftJoin('gnu.specialite as s', 's.id', '=', 'n.specialite_id')
            ->whereRaw('upper(d.code_de) = ?', ['INFO'])
            ->whereRaw('upper(f.code_f) = ?', ['INF'])
            ->orderBy('n.code_niv')
            ->get([
                'n.id as source_niveau_id', 'n.code_niv', 'n.cycle_niv', 'n.libelle_niv',
                'n.specialite_id as source_specialite_id', 'f.id as source_filiere_id',
                'f.code_f', 'f.nom_f', 's.code_specialite as source_specialite_code',
                's.libelle_specialite as source_specialite_name',
            ]);
    }
}
