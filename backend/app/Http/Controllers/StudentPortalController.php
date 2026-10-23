<?php

namespace App\Http\Controllers;

use App\Services\AcademicRules;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\ValidationException;

class StudentPortalController extends Controller
{
    public function academicSheet(Request $request): JsonResponse
    {
        $context = $this->studentContext($request);
        $path = $this->academicSheetPath($context);
        $disk = Storage::disk('local');
        $metadata = $disk->exists($path.'.json')
            ? json_decode($disk->get($path.'.json'), true)
            : [];
        $semesterStates = DB::table('gnu.inscription_semestre')
            ->where('inscription_classe_id', $context->inscription_classe_id)
            ->get(['numero_semestre', 'statut', 'date_soumission'])
            ->keyBy('numero_semestre');

        return response()->json(['data' => [
            'available' => $disk->exists($path),
            'filename' => is_array($metadata) ? ($metadata['filename'] ?? 'fiche-academique-reference.pdf') : 'fiche-academique-reference.pdf',
            'importee_le' => is_array($metadata) ? ($metadata['importee_le'] ?? null) : null,
            'annee_academique' => $context->annee,
            'classe' => $context->code_classe,
            'inscription_classe_id' => (int) $context->inscription_classe_id,
            'statut_inscription' => $context->statut_inscription,
            'semestres' => collect([1, 2])->map(function (int $semester) use ($semesterStates, $request): array {
                $state = $semesterStates->get($semester);

                return [
                    'numero' => $semester,
                    'statut' => $state->statut ?? 'BROUILLON',
                    'date_soumission' => $state?->date_soumission,
                    'motif' => ($state->statut ?? null) === 'REFUSEE'
                        ? $this->latestEnrollmentDecision($request, $semester)
                        : null,
                ];
            })->all(),
        ]]);
    }

    public function storeAcademicSheet(Request $request): JsonResponse
    {
        $request->validate([
            'fiche' => ['required', 'file', 'mimes:pdf', 'max:15360'],
        ]);
        $context = $this->studentContext($request);
        $path = $this->academicSheetPath($context);
        $disk = Storage::disk('local');
        $directory = dirname($path);
        $filename = basename($request->file('fiche')->getClientOriginalName());
        $temporaryPath = $request->file('fiche')->store($directory.'/.pending', 'local');
        abort_if($temporaryPath === false, 500, 'La fiche académique n’a pas pu être enregistrée.');
        $disk->delete($path);
        abort_unless($disk->move($temporaryPath, $path), 500, 'La fiche académique n’a pas pu être finalisée.');
        $disk->put($path.'.json', json_encode([
            'filename' => $filename,
            'importee_le' => now()->toIso8601String(),
        ], JSON_THROW_ON_ERROR));

        return response()->json(['message' => 'La fiche académique a été enregistrée.', 'data' => [
            'available' => true,
            'filename' => $filename,
            'importee_le' => now()->toIso8601String(),
            'annee_academique' => $context->annee,
            'classe' => $context->code_classe,
        ]]);
    }

    public function downloadAcademicSheet(Request $request): mixed
    {
        $context = $this->studentContext($request);
        $path = $this->academicSheetPath($context);
        abort_unless(Storage::disk('local')->exists($path), 404, 'Aucune fiche académique importée pour cette inscription.');

        return Storage::disk('local')->download($path, 'fiche-academique-reference.pdf', [
            'Content-Type' => 'application/pdf',
        ]);
    }

    public function sharedAcademicSheet(Request $request, int $inscriptionClasse): mixed
    {
        $context = DB::table('gnu.inscription_classe as ic')
            ->join('gnu.etudiant as e', 'e.id', '=', 'ic.etudiant_id')
            ->where('ic.id', $inscriptionClasse)
            ->where('e.utilisateur_id', $request->user()->id)
            ->where('ic.statut_inscription', 'VALIDEE')
            ->first(['e.id as etudiant_id', 'ic.id as inscription_classe_id']);
        abort_unless($context !== null, 404);
        $path = $this->academicSheetPath($context);
        abort_unless(Storage::disk('local')->exists($path), 404, 'Aucune fiche académique importée pour cette inscription.');

        return Storage::disk('local')->download($path, 'fiche-academique-reference.pdf', [
            'Content-Type' => 'application/pdf',
        ]);
    }

    public function enrollment(Request $request): JsonResponse
    {
        $semester = $request->integer('semestre', 1);
        abort_unless(in_array($semester, [1, 2], true), 422, 'Le semestre doit être 1 ou 2.');

        $context = $this->studentContext($request);
        abort_unless($context->statut_inscription === 'VALIDEE', 403, 'Votre inscription de classe doit être validée par la scolarité avant de choisir vos UE.');
        $availableSemesters = $context->code_niv === 'M2' ? [2] : [1, 2];
        if (! in_array($semester, $availableSemesters, true)) {
            $semester = $availableSemesters[0];
        }
        $semesterState = DB::table('gnu.inscription_semestre')
            ->where('inscription_classe_id', $context->inscription_classe_id)
            ->where('numero_semestre', $semester)->first();
        $units = DB::table('gnu.ue as u')
            ->where('u.niveau_id', $context->niveau_id)
            ->where('u.version_programme', $context->version_programme)
            ->where('u.numero_semestre', $semester)
            ->where('u.statut_catalogue', 'ACTIF')
            ->orderBy('u.code_ue')
            ->get(['u.id', 'u.code_ue', 'u.code_ue as code', 'u.intitule_ue as intitule', 'u.credit_ue as credits', 'u.categorie_ue as categorie']);

        $selectedIds = DB::table('gnu.inscription_ue')
            ->where('inscription_classe_id', $context->inscription_classe_id)
            ->where('statut_inscription', '!=', 'ANNULEE')
            ->pluck('ue_id')->all();
        $registrationLines = DB::table('gnu.inscription_ue')
            ->where('inscription_classe_id', $context->inscription_classe_id)
            ->whereIn('ue_id', $units->pluck('id'))
            ->get(['ue_id', 'type_inscription', 'statut_inscription'])
            ->keyBy('ue_id');
        $repeatSources = (bool) $context->statut_redoublant
            ? $this->repeatSourcesForSemester($context, $units->all(), $semester)
            : [];

        $data = $units->map(function (object $unit) use ($context, $selectedIds, $registrationLines, $repeatSources): array {
            $teaching = DB::table('gnu.matiere as m')
                ->leftJoin('gnu.affectation as a', function ($join) use ($context): void {
                    $join->on('a.matiere_id', '=', 'm.id')
                        ->where('a.classe_id', '=', $context->classe_id)
                        ->where('a.actif', '=', true);
                })
                ->leftJoin('gnu.enseignant as e', 'e.id', '=', 'a.enseignant_id')
                ->leftJoin('gnu.utilisateur as p', 'p.id', '=', 'e.utilisateur_id')
                ->where('m.ue_id', $unit->id)
                ->orderBy('m.rang_ec')
                ->get(['m.code_m', 'm.intitule_matiere', 'a.id as affectation_id', 'p.nom', 'p.prenom', 'p.actif as enseignant_actif']);

            $professors = $teaching->map(fn (object $row): string => trim(($row->prenom ?? '').' '.($row->nom ?? '')))
                ->filter()->unique()->values()->all();
            $weightProfiles = [];
            foreach ($teaching->pluck('affectation_id')->filter()->unique() as $assignmentId) {
                $plan = DB::table('gnu.plan_evaluation as pe')
                    ->join('gnu.ligne_plan as lp', 'lp.plan_id', '=', 'pe.id')
                    ->join('gnu.evaluation as ev', 'ev.id', '=', 'lp.evaluation_id')
                    ->where('pe.affectation_id', $assignmentId)
                    ->where('pe.statut_plan', 'ACTIF')
                    ->where('pe.portee', 'CLASSE')
                    ->orderByDesc('pe.version_plan')
                    ->get(['ev.type_eval', 'lp.poids_evaluation']);
                $assignmentWeights = [];
                foreach ($plan as $line) {
                    $type = strtoupper((string) $line->type_eval);
                    $key = str_contains($type, 'TPE') ? 'TPE' : (str_contains($type, 'TP') ? 'TP' : (str_contains($type, 'CC') || str_contains($type, 'CONTROLE') ? 'CC' : (str_contains($type, 'SN') || str_contains($type, 'SESSION') || str_contains($type, 'EXAM') ? 'SN' : null)));
                    if ($key !== null) {
                        $assignmentWeights[$key] = ($assignmentWeights[$key] ?? 0) + (int) round((float) $line->poids_evaluation);
                    }
                }
                if ($assignmentWeights !== []) {
                    ksort($assignmentWeights);
                    $weightProfiles[json_encode($assignmentWeights)] = $assignmentWeights;
                }
            }
            $weights = count($weightProfiles) === 1 ? reset($weightProfiles) : [];
            $profileLabels = collect(array_values($weightProfiles))
                ->map(fn (array $profile): string => collect(['CC', 'TP', 'TPE', 'SN'])
                    ->filter(fn (string $key): bool => array_key_exists($key, $profile))
                    ->map(fn (string $key): string => $key.' '.$profile[$key].'%')
                    ->implode(' · '))
                ->values();
            $weightLabel = $profileLabels->isEmpty() ? null : ($profileLabels->count() === 1
                ? $profileLabels->first()
                : 'Selon l’EC : '.$profileLabels->implode(' / '));

            $registration = $registrationLines->get($unit->id);
            $source = $repeatSources[$unit->code_ue] ?? null;
            $isRepeatable = (bool) ($source['a_reprendre'] ?? false);
            $isPreserved = (bool) ($source['acquise'] ?? false);

            return [
                'id' => (int) $unit->id,
                'code' => $unit->code,
                'intitule' => $unit->intitule,
                'credits' => (int) $unit->credits,
                'categorie' => $unit->categorie,
                'obligatoire' => strtoupper((string) $unit->categorie) !== 'OPTIONNELLE',
                'selectionnee' => (bool) $context->statut_redoublant
                    ? ($registration?->type_inscription === 'REPRISE' && $registration?->statut_inscription !== 'ANNULEE')
                    : in_array((int) $unit->id, array_map('intval', $selectedIds), true),
                'type_inscription' => $registration?->type_inscription,
                'selectionnable' => ! (bool) $context->statut_redoublant || $isRepeatable,
                'reprise_possible' => $isRepeatable,
                'conservee' => $isPreserved || $registration?->type_inscription === 'CONSERVEE',
                'note_precedente_sur_20' => $source['note_sur_20'] ?? null,
                'enseignants' => $professors,
                'elements' => $teaching->filter(fn (object $row): bool => $row->affectation_id !== null && $row->enseignant_actif === true)
                    ->unique('code_m')->map(fn (object $row): array => [
                        'code_m' => $row->code_m,
                        'intitule' => $row->intitule_matiere,
                    ])->values(),
                'ponderations' => $weights,
                'ponderation_libelle' => $weightLabel,
            ];
        })->values();

        return response()->json(['data' => [
            'inscription_classe_id' => (int) $context->inscription_classe_id,
            'classe' => $context->code_classe,
            'annee_academique' => $context->annee,
            'redoublant' => (bool) $context->statut_redoublant,
            'niveau' => $context->code_niv,
            'semestres_disponibles' => $availableSemesters,
            'statut' => $semesterState->statut ?? 'BROUILLON',
            'nombre_ue_attendu' => (bool) $context->statut_redoublant
                ? collect($repeatSources)->where('a_reprendre', true)->count()
                : ($context->code_niv === 'M2' ? $units->count() : 6),
            'nombre_ue_reprise_disponible' => collect($repeatSources)->where('a_reprendre', true)->count(),
            'nombre_ue_disponible' => $units->count(),
            'date_soumission' => $semesterState?->date_soumission,
            'motif_decision' => ($semesterState->statut ?? null) === 'REFUSEE'
                ? $this->latestEnrollmentDecision($request, $semester)
                : null,
            'fiche_disponible' => Storage::disk('local')->exists($this->academicSheetPath($context)),
            'semestre' => $semester,
            'peut_modifier' => in_array($semesterState->statut ?? 'BROUILLON', ['BROUILLON', 'SOUMISE', 'REFUSEE'], true),
            'unites' => $data,
        ]]);
    }

    public function saveEnrollment(Request $request): JsonResponse
    {
        $data = $request->validate([
            'semestre' => ['required', 'integer', 'between:1,2'],
            'codes_ue' => ['present', 'array', 'max:100'],
            'codes_ue.*' => ['required', 'string', 'distinct', 'max:32'],
        ]);
        $context = $this->studentContext($request);
        abort_unless($context->statut_inscription === 'VALIDEE', 403, 'Votre inscription de classe doit être validée par la scolarité avant de choisir vos UE.');
        $semester = (int) $data['semestre'];
        abort_unless($context->code_niv !== 'M2' || $semester === 2, 422, 'En M2, seules les UE du semestre 2 sont proposées.');
        $semesterState = DB::table('gnu.inscription_semestre')->where('inscription_classe_id', $context->inscription_classe_id)->where('numero_semestre', $semester)->value('statut');
        abort_unless($semesterState === null || in_array($semesterState, ['BROUILLON', 'SOUMISE', 'REFUSEE'], true), 409, 'Les choix de ce semestre ont déjà été validés.');
        $available = DB::table('gnu.ue')
            ->where('niveau_id', $context->niveau_id)
            ->where('version_programme', $context->version_programme)
            ->where('numero_semestre', $semester)
            ->where('statut_catalogue', 'ACTIF')
            ->get(['id', 'code_ue']);
        $byCode = $available->keyBy('code_ue');
        $codes = array_values(array_unique($data['codes_ue']));
        $repeatSources = (bool) $context->statut_redoublant
            ? $this->repeatSourcesForSemester($context, $available->all(), $semester)
            : [];
        $maximumSelections = (bool) $context->statut_redoublant
            ? collect($repeatSources)->where('a_reprendre', true)->count()
            : ($context->code_niv === 'M2' ? $available->count() : 6);
        abort_if(count($codes) > $maximumSelections, 422, 'Vous ne pouvez pas sélectionner plus de '.$maximumSelections.' UE pour ce semestre.');
        $unknown = array_values(array_diff($codes, $byCode->keys()->all()));
        if ($unknown !== []) {
            throw ValidationException::withMessages(['codes_ue' => ['Une ou plusieurs UE ne sont pas proposées pour ce semestre.']]);
        }
        if ((bool) $context->statut_redoublant) {
            $allowedCodes = collect($repeatSources)
                ->filter(fn (array $source): bool => $source['a_reprendre'])
                ->keys()->all();
            $invalidRetakes = array_values(array_diff($codes, $allowedCodes));
            if ($invalidRetakes !== []) {
                throw ValidationException::withMessages(['codes_ue' => ['Un étudiant redoublant ne peut sélectionner que les UE non acquises de son bulletin précédent.']]);
            }
        }
        $unitIds = $available->pluck('id')->map(fn ($id): int => (int) $id)->all();
        $selectedIds = collect($codes)->map(fn (string $code): int => (int) $byCode[$code]->id)->all();

        DB::transaction(function () use ($request, $context, $available, $unitIds, $selectedIds, $semester, $repeatSources): void {
            $this->setAuditContext($request, 'Enregistrement du brouillon d’inscription pédagogique');
            DB::table('gnu.inscription_semestre')->updateOrInsert(
                ['inscription_classe_id' => $context->inscription_classe_id, 'numero_semestre' => $semester],
                ['statut' => 'BROUILLON', 'date_soumission' => null, 'updated_at' => now()],
            );

            if ((bool) $context->statut_redoublant) {
                foreach ($available as $unit) {
                    $source = $repeatSources[$unit->code_ue] ?? null;
                    $isSelectedForRepeat = in_array((int) $unit->id, $selectedIds, true);
                    $isPreserved = (bool) ($source['acquise'] ?? false);
                    if (! $isSelectedForRepeat && ! $isPreserved) {
                        DB::table('gnu.inscription_ue')->where('inscription_classe_id', $context->inscription_classe_id)
                            ->where('ue_id', $unit->id)->update([
                                'type_inscription' => 'NORMALE',
                                'statut_inscription' => 'ANNULEE',
                                'bulletin_source_id' => null,
                                'ue_source_id' => null,
                                'updated_at' => now(),
                            ]);

                        continue;
                    }

                    if ($source === null) {
                        continue;
                    }
                    DB::table('gnu.inscription_ue')->updateOrInsert(
                        ['inscription_classe_id' => $context->inscription_classe_id, 'ue_id' => $unit->id],
                        [
                            'type_inscription' => $isSelectedForRepeat ? 'REPRISE' : 'CONSERVEE',
                            'statut_inscription' => 'BROUILLON',
                            'bulletin_source_id' => $source['bulletin_id'],
                            'ue_source_id' => $source['ue_source_id'],
                            'updated_at' => now(),
                        ],
                    );
                }

                return;
            }

            DB::table('gnu.inscription_ue')
                ->where('inscription_classe_id', $context->inscription_classe_id)
                ->whereIn('ue_id', $unitIds)
                ->whereNotIn('ue_id', $selectedIds ?: [-1])
                ->update(['statut_inscription' => 'ANNULEE', 'updated_at' => now()]);
            foreach ($selectedIds as $unitId) {
                DB::table('gnu.inscription_ue')->updateOrInsert(
                    ['inscription_classe_id' => $context->inscription_classe_id, 'ue_id' => $unitId],
                    [
                        'type_inscription' => 'NORMALE',
                        'statut_inscription' => 'BROUILLON',
                        'bulletin_source_id' => null,
                        'ue_source_id' => null,
                        'updated_at' => now(),
                    ],
                );
            }
        });

        return $this->enrollment($request->merge(['semestre' => $semester]));
    }

    public function submitEnrollment(Request $request): JsonResponse
    {
        $data = $request->validate(['semestre' => ['required', 'integer', 'between:1,2']]);
        $context = $this->studentContext($request);
        $semester = (int) $data['semestre'];
        abort_unless($context->code_niv !== 'M2' || $semester === 2, 422, 'En M2, seules les UE du semestre 2 sont proposées.');
        $semesterState = DB::table('gnu.inscription_semestre')->where('inscription_classe_id', $context->inscription_classe_id)->where('numero_semestre', $semester)->value('statut');
        abort_unless($semesterState === null || in_array($semesterState, ['BROUILLON', 'SOUMISE', 'REFUSEE'], true), 409, 'Les choix de ce semestre ont déjà été validés.');

        $selectedCount = DB::table('gnu.inscription_ue as iu')
            ->join('gnu.ue as u', 'u.id', '=', 'iu.ue_id')
            ->where('iu.inscription_classe_id', $context->inscription_classe_id)
            ->where('iu.statut_inscription', '!=', 'ANNULEE')
            ->where('u.niveau_id', $context->niveau_id)
            ->where('u.version_programme', $context->version_programme)
            ->where('u.numero_semestre', $semester)
            ->count();
        $availableCount = DB::table('gnu.ue')
            ->where('niveau_id', $context->niveau_id)
            ->where('version_programme', $context->version_programme)
            ->where('numero_semestre', $semester)
            ->where('statut_catalogue', 'ACTIF')
            ->count();
        $expectedCount = $context->code_niv === 'M2' ? $availableCount : 6;
        if ((bool) $context->statut_redoublant) {
            $repeatCount = DB::table('gnu.inscription_ue as iu')
                ->join('gnu.ue as u', 'u.id', '=', 'iu.ue_id')
                ->where('iu.inscription_classe_id', $context->inscription_classe_id)
                ->where('iu.statut_inscription', '!=', 'ANNULEE')
                ->where('iu.type_inscription', 'REPRISE')
                ->where('u.niveau_id', $context->niveau_id)
                ->where('u.version_programme', $context->version_programme)
                ->where('u.numero_semestre', $semester)
                ->count();
            abort_if($repeatCount === 0, 422, 'Sélectionnez au moins une UE non acquise à reprendre avant de soumettre.');
        } else {
            abort_if($availableCount < $expectedCount, 409, 'Le catalogue ne contient que '.$availableCount.' UE actives pour ce semestre; '.$expectedCount.' sont requises. Contactez l’agent du département.');
            abort_if($expectedCount === 0, 422, 'Aucune UE active n’est configurée pour ce semestre.');
            abort_if($selectedCount !== $expectedCount, 422, 'Sélectionnez exactement '.$expectedCount.' UE pour ce semestre avant de soumettre.');
        }

        DB::transaction(function () use ($request, $context, $semester): void {
            $this->setAuditContext($request, 'Soumission de l’inscription pédagogique');
            DB::table('gnu.inscription_semestre')->updateOrInsert(
                ['inscription_classe_id' => $context->inscription_classe_id, 'numero_semestre' => $semester],
                ['statut' => 'SOUMISE', 'date_soumission' => now(), 'updated_at' => now()],
            );
        });

        return $this->enrollment($request->merge(['semestre' => $semester]));
    }

    public function results(Request $request): JsonResponse
    {
        $context = $this->studentContext($request);
        abort_unless($context->statut_inscription === 'VALIDEE', 403, 'Votre inscription de classe doit être validée pour consulter vos bulletins.');
        $period = $request->query('periode');
        abort_if($period !== null && ! in_array($period, ['S1', 'S2', 'ANNUELLE'], true), 422, 'Période invalide.');
        $query = DB::table('gnu.bulletin as b')
            ->join('gnu.publication as p', 'p.id', '=', 'b.publication_id')
            ->where('b.inscription_classe_id', $context->inscription_classe_id)
            ->where('b.courant', true)
            ->orderBy('b.periode');
        if ($period !== null) {
            $query->where('b.periode', $period);
        }
        $data = $query->get([
            'b.id', 'b.periode', 'b.version_bulletin', 'b.mgp_s1', 'b.mgp_s2', 'b.mgp_total',
            'b.total_credits', 'b.decision_admission', 'b.contenu_fige', 'p.date_publication',
        ])->map(function (object $bulletin): array {
            $snapshot = is_string($bulletin->contenu_fige) ? json_decode($bulletin->contenu_fige, true) : (array) $bulletin->contenu_fige;
            $snapshot = $this->annotateEvaluationTypes($snapshot);

            return [
                'id' => (int) $bulletin->id,
                'periode' => $bulletin->periode,
                'version' => (int) $bulletin->version_bulletin,
                'mgp_s1' => $bulletin->mgp_s1,
                'mgp_s2' => $bulletin->mgp_s2,
                'mgp_total' => $bulletin->mgp_total,
                'credits' => $bulletin->total_credits,
                'decision' => $bulletin->decision_admission,
                'publie_le' => $bulletin->date_publication,
                'contenu' => $snapshot,
            ];
        })->values();

        return response()->json(['data' => $data]);
    }

    public function provisionalResults(Request $request): JsonResponse
    {
        $context = $this->studentContext($request);
        abort_unless($context->statut_inscription === 'VALIDEE', 403, 'Votre inscription de classe doit être validée pour consulter le bulletin provisoire.');
        $period = $request->query('periode', 'S1');
        abort_unless(in_array($period, ['S1', 'S2', 'ANNUELLE'], true), 422, 'Période invalide.');
        $result = DB::selectOne('SELECT gnu.previsualiser_bulletin(?, ?) AS contenu', [$context->inscription_classe_id, $period]);
        $content = is_string($result->contenu) ? json_decode($result->contenu, true, flags: JSON_THROW_ON_ERROR) : (array) $result->contenu;
        $content = $this->annotateEvaluationTypes($content);

        return response()->json(['data' => [
            'statut' => 'PROVISOIRE',
            'periode' => $period,
            'calcule_le' => now()->toIso8601String(),
            'contenu' => $content,
        ]]);
    }

    public function requests(Request $request): JsonResponse
    {
        abort_unless($this->studentContext($request)->statut_inscription === 'VALIDEE', 403, 'Votre inscription de classe doit être validée pour soumettre ou consulter des requêtes.');
        $studentId = $this->studentId($request);
        $decisions = DB::table('gnu.decision_requete')->where('courante', true)->select('requete_id', 'action_decision', 'motif', 'date_decision');
        $rows = DB::table('gnu.requete as r')
            ->join('gnu.inscription_ue as iu', 'iu.id', '=', 'r.inscription_ue_id')
            ->join('gnu.inscription_classe as ic', 'ic.id', '=', 'iu.inscription_classe_id')
            ->join('gnu.ue as u', 'u.id', '=', 'iu.ue_id')
            ->leftJoinSub($decisions, 'd', 'd.requete_id', '=', 'r.id')
            ->leftJoin('gnu.justificatif as j', 'j.requete_id', '=', 'r.id')
            ->where('ic.etudiant_id', $studentId)
            ->orderByDesc('r.date_soumission')
            ->get(['r.id', 'u.code_ue', 'r.objet', 'r.description', 'r.type_requete', 'r.statut_requete', 'r.date_soumission', 'd.action_decision', 'd.motif as decision_motif', 'd.date_decision', 'j.requete_id as justificatif_id']);

        return response()->json(['data' => $rows->map(fn (object $row): array => [
            'id' => (int) $row->id,
            'code_ue' => $row->code_ue,
            'type' => $row->type_requete,
            'titre' => $row->type_requete === 'CANDIDATURE_RATTRAPAGE'
                ? 'Candidature au rattrapage'
                : $row->objet,
            'message' => $row->description,
            'statut' => $row->statut_requete,
            'decision' => $row->action_decision,
            'motif_decision' => $row->decision_motif,
            'soumise_le' => $row->date_soumission,
            'decidee_le' => $row->date_decision,
            'a_justificatif' => $row->justificatif_id !== null,
        ])]);
    }

    public function missingEvaluations(Request $request): JsonResponse
    {
        $data = $request->validate([
            'code_ue' => ['required', 'string', 'max:32'],
            'code_m' => ['required', 'string', 'max:32'],
        ]);
        $context = $this->studentContext($request);
        abort_unless($context->statut_inscription === 'VALIDEE', 403, 'Votre inscription doit être validée pour signaler une note manquante.');

        $rows = DB::table('gnu.inscription_ue as iu')
            ->join('gnu.ue as u', 'u.id', '=', 'iu.ue_id')
            ->join('gnu.matiere as m', 'm.ue_id', '=', 'iu.ue_id')
            ->join('gnu.affectation as a', function ($join) use ($context): void {
                $join->on('a.matiere_id', '=', 'm.id')
                    ->where('a.classe_id', '=', $context->classe_id)
                    ->where('a.actif', true);
            })
            ->join('gnu.evaluation as ev', 'ev.affectation_id', '=', 'a.id')
            ->join('gnu.ligne_plan as lp', function ($join): void {
                $join->on('lp.evaluation_id', '=', 'ev.id')->where('lp.retenue', true);
            })
            ->join('gnu.plan_evaluation as pe', function ($join): void {
                $join->on('pe.id', '=', 'lp.plan_id')->where('pe.affectation_id', '=', 'a.id')
                    ->where('pe.portee', 'CLASSE')->where('pe.statut_plan', 'ACTIF');
            })
            ->leftJoin('gnu.note as n', function ($join): void {
                $join->on('n.evaluation_id', '=', 'ev.id')
                    ->on('n.inscription_ue_id', '=', 'iu.id');
            })
            ->where('iu.inscription_classe_id', $context->inscription_classe_id)
            ->where('iu.statut_inscription', 'VALIDEE')
            ->where('u.code_ue', $data['code_ue'])
            ->where('m.code_m', $data['code_m'])
            ->where('ev.mode_evaluation', 'NORMALE')
            ->where('ev.statut_evaluation', 'REALISEE')
            ->where(function ($query): void {
                $query->whereNull('n.id')->orWhere('n.situation', 'MANQUANTE');
            })
            ->whereNotExists(function ($query): void {
                $query->selectRaw('1')
                    ->from('gnu.requete as r')
                    ->whereColumn('r.evaluation_id', 'ev.id')
                    ->whereColumn('r.inscription_ue_id', 'iu.id')
                    ->where('r.type_requete', 'NOTE_MANQUANTE')
                    ->whereIn('r.statut_requete', ['SOUMISE', 'EN_TRAITEMENT']);
            })
            ->orderBy('ev.date_evaluation')
            ->orderBy('ev.id')
            ->get(['ev.id', 'ev.type_eval', 'ev.date_evaluation']);

        return response()->json(['data' => $rows->map(static fn (object $row): array => [
            'id' => (int) $row->id,
            'type_eval' => $row->type_eval,
            'date_evaluation' => $row->date_evaluation,
        ])]);
    }

    public function createRequest(Request $request): JsonResponse
    {
        $data = $request->validate([
            'code_ue' => ['required', 'string', 'max:32'],
            'code_m' => ['required', 'string', 'max:32'],
            'type' => ['required', 'in:Vérification de note,Note manquante,Absence justifiée,Autre demande'],
            'evaluation_id' => ['required_if:type,Note manquante', 'nullable', 'integer', 'min:1', 'prohibited_unless:type,Note manquante'],
            'message' => ['required', 'string', 'min:15', 'max:1500'],
            'justificatif' => ['nullable', 'file', 'mimes:pdf,png,jpg,jpeg', 'max:5120'],
        ]);
        $studentId = $this->studentId($request);
        $type = match ($data['type']) {
            'Vérification de note' => 'CONTESTATION',
            'Note manquante' => 'NOTE_MANQUANTE',
            'Absence justifiée' => 'ABSENCE',
            default => 'AUTRE',
        };
        $studentContext = $type === 'NOTE_MANQUANTE' ? $this->studentContext($request) : null;
        $registrationUnit = DB::table('gnu.inscription_ue as iu')
            ->join('gnu.inscription_classe as ic', 'ic.id', '=', 'iu.inscription_classe_id')
            ->join('gnu.ue as u', 'u.id', '=', 'iu.ue_id')
            ->where('ic.etudiant_id', $studentId)
            ->when($studentContext !== null, fn ($query) => $query->where('ic.id', $studentContext->inscription_classe_id))
            ->where('u.code_ue', $data['code_ue'])
            ->where('iu.statut_inscription', '!=', 'ANNULEE')
            ->orderByDesc('ic.id')->first([
                'iu.id', 'iu.statut_inscription as statut_inscription_ue',
                'ic.id as inscription_classe_id', 'ic.classe_id', 'ic.statut_inscription as statut_inscription_classe',
                'u.id as ue_id',
            ]);
        abort_unless($registrationUnit !== null, 422, 'Cette UE ne fait pas partie de vos inscriptions.');

        $courseId = DB::table('gnu.matiere as m')
            ->join('gnu.affectation as a', function ($join) use ($registrationUnit): void {
                $join->on('a.matiere_id', '=', 'm.id')->where('a.classe_id', '=', $registrationUnit->classe_id)->where('a.actif', '=', true);
            })
            ->join('gnu.enseignant as e', 'e.id', '=', 'a.enseignant_id')
            ->join('gnu.utilisateur as teacher', 'teacher.id', '=', 'e.utilisateur_id')
            ->where('m.ue_id', $registrationUnit->ue_id)->where('m.code_m', $data['code_m'])->where('teacher.actif', true)
            ->value('m.id');
        abort_unless($courseId !== null, 422, 'Cet EC n’est pas rattaché à une affectation active de votre classe.');

        $evaluationId = null;
        $noteId = null;
        if ($type === 'NOTE_MANQUANTE') {
            abort_unless(
                $registrationUnit->statut_inscription_classe === 'VALIDEE'
                    && $registrationUnit->statut_inscription_ue === 'VALIDEE',
                403,
                'Votre inscription à la classe et à l’UE doit être validée pour signaler une note manquante.',
            );
            $missingNote = DB::table('gnu.evaluation as ev')
                ->join('gnu.affectation as a', function ($join) use ($registrationUnit, $courseId): void {
                    $join->on('a.id', '=', 'ev.affectation_id')
                        ->where('a.matiere_id', '=', $courseId)
                        ->where('a.classe_id', '=', $registrationUnit->classe_id)
                        ->where('a.actif', true);
                })
                ->join('gnu.ligne_plan as lp', function ($join): void {
                    $join->on('lp.evaluation_id', '=', 'ev.id')->where('lp.retenue', true);
                })
                ->join('gnu.plan_evaluation as pe', function ($join): void {
                    $join->on('pe.id', '=', 'lp.plan_id')
                        ->whereColumn('pe.affectation_id', 'a.id')
                        ->where('pe.portee', 'CLASSE')->where('pe.statut_plan', 'ACTIF');
                })
                ->leftJoin('gnu.note as n', function ($join) use ($registrationUnit): void {
                    $join->on('n.evaluation_id', '=', 'ev.id')
                        ->where('n.inscription_ue_id', '=', $registrationUnit->id);
                })
                ->where('ev.id', $data['evaluation_id'])
                ->where('ev.mode_evaluation', 'NORMALE')
                ->where('ev.statut_evaluation', 'REALISEE')
                ->where(function ($query): void {
                    $query->whereNull('n.id')->orWhere('n.situation', 'MANQUANTE');
                })
                ->first(['ev.id', 'n.id as note_id']);
            abort_unless($missingNote !== null, 422, 'Cette évaluation ne comporte pas de note manquante pour votre inscription.');
            $evaluationId = (int) $missingNote->id;
            $noteId = $missingNote->note_id === null ? null : (int) $missingNote->note_id;
            abort_if(DB::table('gnu.requete')
                ->where('inscription_ue_id', $registrationUnit->id)
                ->where('evaluation_id', $evaluationId)
                ->where('type_requete', 'NOTE_MANQUANTE')
                ->whereIn('statut_requete', ['SOUMISE', 'EN_TRAITEMENT'])
                ->exists(), 409, 'Une requête pour cette note manquante est déjà en cours de traitement.');
        }
        $bulletinId = null;
        if ($type === 'CONTESTATION') {
            $bulletinId = DB::table('gnu.bulletin')
                ->where('inscription_classe_id', $registrationUnit->inscription_classe_id)
                ->where('courant', true)->orderByDesc('version_bulletin')->value('id');
            abort_if($bulletinId === null, 409, 'Une contestation de note est possible après publication du bulletin concerné.');
        }

        $file = $request->file('justificatif');
        $storedPath = null;
        if ($file !== null) {
            $storedPath = $file->store('justificatifs-etudiants', 'local');
            abort_if($storedPath === false, 500, 'Le justificatif n’a pas pu être enregistré.');
        }

        try {
            $requestId = DB::transaction(function () use ($request, $data, $registrationUnit, $type, $bulletinId, $courseId, $evaluationId, $noteId, $file, $storedPath): int {
                $this->setAuditContext($request, 'Dépôt d’une requête étudiante');
                $now = now();
                $id = DB::table('gnu.requete')->insertGetId([
                    'inscription_ue_id' => $registrationUnit->id,
                    'matiere_id' => $courseId,
                    'evaluation_id' => $evaluationId,
                    'note_id' => $noteId,
                    'bulletin_conteste_id' => $bulletinId,
                    'objet' => $data['type'],
                    'description' => trim($data['message']),
                    'type_requete' => $type,
                    'statut_requete' => 'SOUMISE',
                    'date_soumission' => $now,
                    'created_at' => $now,
                    'updated_at' => $now,
                ], 'id');
                if ($file !== null && $storedPath !== null) {
                    DB::table('gnu.justificatif')->insert([
                        'requete_id' => $id,
                        'reference_fichier_prive' => $storedPath,
                        'type_fichier' => $file->getMimeType() ?? 'application/octet-stream',
                        'taille_octets' => $file->getSize(),
                        'empreinte' => hash_file('sha256', $file->getRealPath()),
                        'date_depot' => $now,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ]);
                }

                return (int) $id;
            });
        } catch (\Throwable $exception) {
            if ($storedPath !== null) {
                Storage::disk('local')->delete($storedPath);
            }
            throw $exception;
        }

        return response()->json(['message' => 'Votre requête a été transmise.', 'id' => $requestId], 201);
    }

    public function downloadJustificatif(Request $request, int $requete): mixed
    {
        $studentId = $this->studentId($request);
        $file = DB::table('gnu.justificatif as j')
            ->join('gnu.requete as r', 'r.id', '=', 'j.requete_id')
            ->join('gnu.inscription_ue as iu', 'iu.id', '=', 'r.inscription_ue_id')
            ->join('gnu.inscription_classe as ic', 'ic.id', '=', 'iu.inscription_classe_id')
            ->where('r.id', $requete)->where('ic.etudiant_id', $studentId)
            ->first(['j.reference_fichier_prive', 'j.type_fichier']);
        abort_unless($file !== null && Storage::disk('local')->exists($file->reference_fichier_prive), 404);

        return Storage::disk('local')->response($file->reference_fichier_prive, 'justificatif', ['Content-Type' => $file->type_fichier]);
    }

    public function retakes(Request $request): JsonResponse
    {
        $studentId = $this->studentId($request);
        $context = $this->studentContext($request);
        abort_unless($context->statut_inscription === 'VALIDEE', 403, 'Votre inscription de classe doit être validée pour consulter les rattrapages.');
        $bulletins = DB::table('gnu.bulletin as b')
            ->join('gnu.publication as p', 'p.id', '=', 'b.publication_id')
            ->where('b.inscription_classe_id', $context->inscription_classe_id)
            ->where('b.courant', true)->get(['b.id', 'b.contenu_fige']);
        $registeredUnits = DB::table('gnu.inscription_ue as iu')
            ->join('gnu.ue as u', 'u.id', '=', 'iu.ue_id')
            ->where('iu.inscription_classe_id', $context->inscription_classe_id)
            ->where('iu.statut_inscription', '!=', 'ANNULEE')
            ->get(['iu.id as inscription_ue_id', 'u.id as ue_id', 'u.code_ue', 'u.intitule_ue']);
        $data = [];
        foreach ($bulletins as $bulletin) {
            $snapshot = is_string($bulletin->contenu_fige) ? json_decode($bulletin->contenu_fige, true) : (array) $bulletin->contenu_fige;
            foreach ($registeredUnits as $unit) {
                $mark = app(AcademicRules::class)->markForUnitSnapshot($snapshot, $unit->code_ue);
                if ($mark === null) {
                    continue;
                }
                $application = DB::table('gnu.candidature_rattrapage as cr')
                    ->leftJoin('gnu.session_rattrapage as s', 's.id', '=', 'cr.session_id')
                    ->where('cr.etudiant_id', $studentId)
                    ->where('cr.inscription_ue_id', $unit->inscription_ue_id)
                    ->where('cr.statut_candidature', '!=', 'ANNULEE')
                    ->orderByDesc('cr.id')->first(['cr.id', 'cr.session_id', 'cr.statut_candidature', 's.libelle', 's.date_session', 's.statut_session']);
                $pendingRequest = DB::table('gnu.requete as r')
                    ->join('gnu.requete_rattrapage as rr', 'rr.requete_id', '=', 'r.id')
                    ->join('gnu.session_rattrapage as s', 's.id', '=', 'rr.session_id')
                    ->where('r.inscription_ue_id', $unit->inscription_ue_id)
                    ->where('r.type_requete', 'CANDIDATURE_RATTRAPAGE')
                    ->whereIn('r.statut_requete', ['SOUMISE', 'EN_TRAITEMENT'])
                    ->orderByDesc('r.date_soumission')
                    ->first(['r.id', 'r.statut_requete', 's.id as session_id', 's.libelle', 's.date_session', 's.statut_session']);
                $session = $application?->session_id !== null
                    ? (object) [
                        'id' => (int) $application->session_id,
                        'libelle' => $application->libelle,
                        'date_session' => $application->date_session,
                        'statut_session' => $application->statut_session,
                    ]
                    : ($pendingRequest !== null
                        ? (object) [
                            'id' => (int) $pendingRequest->session_id,
                            'libelle' => $pendingRequest->libelle,
                            'date_session' => $pendingRequest->date_session,
                            'statut_session' => $pendingRequest->statut_session,
                        ]
                        : DB::table('gnu.session_rattrapage as s')
                            ->leftJoin('gnu.session_rattrapage_ue as su', 'su.session_id', '=', 's.id')
                            ->where('s.classe_id', $context->classe_id)
                            ->where(function ($query) use ($unit): void {
                                $query->where('su.ue_id', $unit->ue_id)->orWhereNull('su.ue_id');
                            })
                            ->whereIn('s.statut_session', ['PREVUE', 'OUVERTE'])
                            ->whereDate('s.date_session', '>=', today())
                            ->orderByRaw('CASE WHEN su.ue_id IS NULL THEN 1 ELSE 0 END')->orderBy('s.date_session')
                            ->first(['s.id', 's.libelle', 's.date_session', 's.statut_session']));
                $existingSessions = DB::table('gnu.candidature_rattrapage')
                    ->where('etudiant_id', $studentId)
                    ->where('inscription_ue_id', $unit->inscription_ue_id)
                    ->where('statut_candidature', '!=', 'ANNULEE')
                    ->whereNotNull('session_id')
                    ->distinct()->count('session_id');
                $eligible = app(AcademicRules::class)->isRetakeEligible($mark, $existingSessions);
                if (! $eligible && $application === null) {
                    continue;
                }
                $data[] = [
                    'id' => $application?->id === null ? null : (int) $application->id,
                    'code_ue' => $unit->code_ue,
                    'intitule' => $unit->intitule_ue,
                    'note_sur_20' => $mark,
                    'seuil_admissibilite_maximum_sur_20' => (float) config('academic.retake_maximum_inclusive', 10),
                    'seuil_admissibilite_maximum_sur_100' => 50,
                    'eligible' => $eligible,
                    'statut' => $pendingRequest?->statut_requete
                        ?? $application?->statut_candidature
                        ?? ($session === null ? 'ELIGIBLE' : 'SESSION_PROGRAMMEE'),
                    'session' => $session?->libelle,
                    'date_session' => $session?->date_session,
                    'statut_session' => $session?->statut_session,
                    'session_id' => $session?->id === null ? null : (int) $session->id,
                    'requete_id' => $pendingRequest?->id === null ? null : (int) $pendingRequest->id,
                    'peut_candidater' => $eligible
                        && $pendingRequest === null
                        && $application?->session_id === null
                        && $session?->statut_session === 'OUVERTE'
                        && $session?->id !== null,
                ];
            }
        }

        return response()->json(['data' => collect($data)->unique('code_ue')->values()]);
    }

    public function applyForRetake(Request $request): JsonResponse
    {
        $data = $request->validate([
            'code_ue' => ['required', 'string', 'max:32'],
            'session_id' => ['required', 'integer', 'min:1'],
        ]);
        $context = $this->studentContext($request);
        abort_unless($context->statut_inscription === 'VALIDEE', 403, 'Votre inscription doit être validée pour candidater à un rattrapage.');

        $unit = DB::table('gnu.inscription_ue as iu')
            ->join('gnu.ue as u', 'u.id', '=', 'iu.ue_id')
            ->where('iu.inscription_classe_id', $context->inscription_classe_id)
            ->where('iu.statut_inscription', 'VALIDEE')
            ->where('u.code_ue', $data['code_ue'])
            ->where('u.statut_catalogue', 'ACTIF')
            ->first(['iu.id as inscription_ue_id', 'u.id as ue_id', 'u.code_ue', 'u.numero_semestre']);
        abort_unless($unit !== null, 422, 'Cette UE ne fait pas partie de vos inscriptions validées.');

        $session = DB::table('gnu.session_rattrapage as s')
            ->leftJoin('gnu.session_rattrapage_ue as su', 'su.session_id', '=', 's.id')
            ->where('s.id', (int) $data['session_id'])
            ->where('s.classe_id', $context->classe_id)
            ->where('s.statut_session', 'OUVERTE')
            ->whereDate('s.date_session', '>=', today())
            ->where(fn ($query) => $query->where('su.ue_id', $unit->ue_id)->orWhereNull('su.ue_id'))
            ->orderByRaw('CASE WHEN su.ue_id = ? THEN 0 ELSE 1 END', [$unit->ue_id])
            ->first(['s.id', 's.libelle', 's.date_session']);
        abort_unless($session !== null, 422, 'Cette session n’est pas ouverte pour votre UE ou sa date est dépassée.');

        $period = 'S'.$unit->numero_semestre;
        $bulletins = DB::table('gnu.bulletin as b')
            ->join('gnu.publication as p', 'p.id', '=', 'b.publication_id')
            ->where('b.inscription_classe_id', $context->inscription_classe_id)
            ->where('b.courant', true)
            ->whereIn('b.periode', [$period, 'ANNUELLE'])
            ->orderByRaw('CASE WHEN b.periode = ? THEN 0 ELSE 1 END', [$period])
            ->orderByDesc('b.version_bulletin')
            ->get(['b.id', 'b.periode', 'b.contenu_fige']);

        $rules = app(AcademicRules::class);
        $sourceBulletin = null;
        $unitResult = null;
        $mark = null;
        foreach ($bulletins as $bulletin) {
            $snapshot = is_string($bulletin->contenu_fige)
                ? json_decode($bulletin->contenu_fige, true, flags: JSON_THROW_ON_ERROR)
                : (array) $bulletin->contenu_fige;
            $result = $this->unitResultFromSnapshot($snapshot, $unit->code_ue);
            $candidateMark = $rules->markForUnitSnapshot(['ues' => $result === null ? [] : [$result]], $unit->code_ue);
            if ($result !== null && $candidateMark !== null) {
                $sourceBulletin = $bulletin;
                $unitResult = $result;
                $mark = $candidateMark;
                break;
            }
        }
        abort_unless($sourceBulletin !== null && $unitResult !== null && $mark !== null, 409, 'Aucun bulletin officiel courant ne permet de confirmer votre admissibilité.');

        $existingSessions = DB::table('gnu.candidature_rattrapage')
            ->where('etudiant_id', $context->etudiant_id)
            ->where('inscription_ue_id', $unit->inscription_ue_id)
            ->where('statut_candidature', '!=', 'ANNULEE')
            ->whereNotNull('session_id')
            ->distinct()->count('session_id');
        abort_unless($rules->isRetakeEligible((float) $mark, $existingSessions), 409, 'Vous n’êtes pas admissible ou vous avez déjà consommé votre session de rattrapage.');

        abort_if(DB::table('gnu.requete as r')
            ->where('r.inscription_ue_id', $unit->inscription_ue_id)
            ->where('r.type_requete', 'CANDIDATURE_RATTRAPAGE')
            ->whereIn('r.statut_requete', ['SOUMISE', 'EN_TRAITEMENT'])
            ->exists(), 409, 'Une demande de candidature est déjà en cours pour cette UE.');

        $components = collect($unitResult['ecs'] ?? [])->filter(fn (mixed $component): bool => is_array($component));
        $componentById = $components->keyBy(fn (array $component): int => (int) ($component['matiere_id'] ?? 0));
        $courses = DB::table('gnu.matiere')->where('ue_id', $unit->ue_id)->orderBy('rang_ec')->get(['id', 'code_m']);
        abort_if($courses->isEmpty(), 409, 'Cette UE ne contient aucun élément constitutif à inscrire au rattrapage.');

        $requestRows = [];
        foreach ($courses as $course) {
            $component = $componentById->get((int) $course->id);
            if ($component === null) {
                $component = $components->first(fn (array $row): bool => ($row['code_m'] ?? null) === $course->code_m);
            }
            if ($component === null
                || (bool) ($component['el'] ?? false)
                || ! is_numeric($component['arrondi'] ?? null)
                || (float) $component['arrondi'] >= 50) {
                continue;
            }
            $sources = collect($component['sources'] ?? [])->filter(fn (mixed $source): bool => is_array($source));
            $originIds = $sources->map(fn (array $source): int => (int) ($source['evaluation_origine_id'] ?? $source['evaluation_id'] ?? 0))
                ->filter(fn (int $id): bool => $id > 0)->unique()->values();
            $evaluationTypes = $originIds->isEmpty()
                ? collect()
                : DB::table('gnu.evaluation')->whereIn('id', $originIds)->pluck('type_eval', 'id');
            $originEvaluationId = $sources->first(function (array $source) use ($evaluationTypes): bool {
                $id = (int) ($source['evaluation_origine_id'] ?? $source['evaluation_id'] ?? 0);

                return $id > 0 && strtoupper((string) $evaluationTypes->get($id)) === 'SN';
            });
            $originEvaluationId = $originEvaluationId === null
                ? null
                : (int) ($originEvaluationId['evaluation_origine_id'] ?? $originEvaluationId['evaluation_id']);
            if ($originEvaluationId === null) {
                continue;
            }

            $requestRows[] = [
                'matiere_id' => (int) $course->id,
                'evaluation_origine_id' => $originEvaluationId,
                'code_m' => $course->code_m,
            ];
        }
        abort_if($requestRows === [], 422, 'Aucun EC de cette UE ne respecte les conditions de rattrapage SN.');

        $requestIds = DB::transaction(function () use ($request, $unit, $session, $requestRows, $sourceBulletin): array {
            DB::table('gnu.inscription_ue')->where('id', $unit->inscription_ue_id)->lockForUpdate()->first();
            $lockedSession = DB::table('gnu.session_rattrapage')->where('id', $session->id)->lockForUpdate()->first();
            abort_unless($lockedSession?->statut_session === 'OUVERTE' && $lockedSession->date_session >= today()->toDateString(), 409, 'La session vient d’être fermée ou sa date est dépassée. Actualisez la page.');
            abort_if(DB::table('gnu.requete as r')
                ->where('r.inscription_ue_id', $unit->inscription_ue_id)
                ->where('r.type_requete', 'CANDIDATURE_RATTRAPAGE')
                ->whereIn('r.statut_requete', ['SOUMISE', 'EN_TRAITEMENT'])
                ->exists(), 409, 'Une demande de candidature est déjà en cours pour cette UE.');
            $this->setAuditContext($request, 'Dépôt d’une demande de rattrapage '.$unit->code_ue);

            $ids = [];
            foreach ($requestRows as $candidate) {
                $description = 'Demande d’inscription à la session '.$session->libelle.' du '.$session->date_session.' pour l’EC '.$candidate['code_m'].' de l’UE '.$unit->code_ue.'.';
                $requestId = (int) DB::table('gnu.requete')->insertGetId([
                    'inscription_ue_id' => $unit->inscription_ue_id,
                    'matiere_id' => $candidate['matiere_id'],
                    'evaluation_id' => $candidate['evaluation_origine_id'],
                    'note_id' => null,
                    'bulletin_conteste_id' => null,
                    'objet' => 'Candidature au rattrapage',
                    'description' => $description,
                    'type_requete' => 'CANDIDATURE_RATTRAPAGE',
                    'statut_requete' => 'SOUMISE',
                    'date_soumission' => now(),
                    'created_at' => now(),
                    'updated_at' => now(),
                ], 'id');
                DB::table('gnu.requete_rattrapage')->insert([
                    'requete_id' => $requestId,
                    'session_id' => $session->id,
                    'bulletin_source_id' => $sourceBulletin->id,
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);
                $ids[] = $requestId;
            }

            return $ids;
        });

        return response()->json([
            'message' => 'Votre demande est transmise à la cellule pour acheminement vers les enseignants responsables. La candidature sera enregistrée après leur autorisation.',
            'session_id' => (int) $session->id,
            'requete_ids' => $requestIds,
        ], 201);
    }

    public function notifications(Request $request): JsonResponse
    {
        $studentId = $this->studentId($request);
        $userId = (int) $request->user()->id;
        $this->syncNotifications($userId, $studentId);
        $rows = DB::table('gnu.notification')->where('destinataire_id', $userId)
            ->orderByDesc('created_at')->limit(100)->get([
                'id', 'type_notification', 'contenu', 'jour_ouvrable', 'date_envoi', 'date_lecture', 'created_at',
            ]);

        return response()->json(['data' => $rows->map(fn (object $row): array => [
            'id' => (int) $row->id,
            'type' => $row->type_notification,
            'contenu' => is_string($row->contenu) ? json_decode($row->contenu, true) : $row->contenu,
            'date' => $row->date_envoi ?? $row->created_at,
            'lue' => $row->date_lecture !== null,
            'jour_ouvrable' => $row->jour_ouvrable,
        ])]);
    }

    public function markNotificationRead(Request $request, int $notification): JsonResponse
    {
        $updated = DB::transaction(function () use ($request, $notification): int {
            $this->setAuditContext($request, 'Lecture d’une notification académique');

            return DB::table('gnu.notification')->where('id', $notification)
                ->where('destinataire_id', $request->user()->id)->update([
                    'date_lecture' => now(),
                    'updated_at' => now(),
                ]);
        });
        abort_unless($updated > 0 || DB::table('gnu.notification')->where('id', $notification)->where('destinataire_id', $request->user()->id)->exists(), 404);

        return response()->json(['message' => 'Notification marquée comme lue.']);
    }

    private function studentContext(Request $request): object
    {
        $query = DB::table('gnu.etudiant as e')
            ->join('gnu.inscription_classe as ic', 'ic.etudiant_id', '=', 'e.id')
            ->join('gnu.classe as c', 'c.id', '=', 'ic.classe_id')
            ->join('gnu.niveau as n', 'n.id', '=', 'c.niveau_id')
            ->join('gnu.annee_academique as an', 'an.id', '=', 'c.annee_id')
            ->where('e.utilisateur_id', $request->user()->id)
            ->where('ic.statut_inscription', '!=', 'ANNULEE')
            ->when($request->filled('annee_id'), fn ($query) => $query->where('c.annee_id', $request->integer('annee_id')))
            ->orderByDesc('an.date_debut')->orderByDesc('ic.id');
        $context = $query->first([
            'e.id as etudiant_id', 'ic.id as inscription_classe_id', 'ic.statut_inscription', 'ic.statut_redoublant',
            'c.id as classe_id', 'c.code_classe', 'c.annee_id', 'c.version_programme', 'n.id as niveau_id', 'n.code_niv',
            'an.libelle as annee', 'an.date_debut as annee_debut',
        ]);
        abort_unless($context !== null, 404, 'Aucune inscription de classe active n’est rattachée à votre compte.');

        return $context;
    }

    /**
     * @param  list<object>  $units
     * @return array<string, array{bulletin_id: int, ue_source_id: int, note_sur_20: ?float, acquise: bool, a_reprendre: bool}>
     */
    private function repeatSourcesForSemester(object $context, array $units, int $semester): array
    {
        if ($units === []) {
            return [];
        }

        $unitCodes = collect($units)->pluck('code_ue')->all();
        $bulletins = DB::table('gnu.bulletin as b')
            ->join('gnu.publication as p', 'p.id', '=', 'b.publication_id')
            ->join('gnu.inscription_classe as ic', 'ic.id', '=', 'b.inscription_classe_id')
            ->join('gnu.classe as c', 'c.id', '=', 'ic.classe_id')
            ->join('gnu.annee_academique as an', 'an.id', '=', 'c.annee_id')
            ->where('ic.etudiant_id', $context->etudiant_id)
            ->where('ic.statut_inscription', 'VALIDEE')
            ->where('c.niveau_id', $context->niveau_id)
            ->where('c.annee_id', '!=', $context->annee_id)
            ->where('an.date_debut', '<', $context->annee_debut)
            ->where('b.courant', true)
            ->whereIn('b.periode', ['S'.$semester, 'ANNUELLE'])
            ->orderByDesc('an.date_debut')
            ->orderByRaw('CASE WHEN b.periode = ? THEN 0 ELSE 1 END', ['S'.$semester])
            ->get(['b.id', 'b.periode', 'b.contenu_fige']);

        $sources = [];
        $rules = app(AcademicRules::class);
        foreach ($units as $unit) {
            foreach ($bulletins as $bulletin) {
                $snapshot = is_string($bulletin->contenu_fige)
                    ? json_decode($bulletin->contenu_fige, true, flags: JSON_THROW_ON_ERROR)
                    : (array) $bulletin->contenu_fige;
                $result = $this->unitResultFromSnapshot($snapshot, $unit->code_ue);
                if ($result === null || ! is_numeric($result['ue_id'] ?? null)) {
                    continue;
                }

                $mark = $rules->markForUnitSnapshot(['ues' => [$result]], $unit->code_ue);
                $eliminated = (bool) ($result['el'] ?? false);
                $minimumMark = (float) config('academic.admission_minimum_ue', 35) / 5;
                $acquired = ! $eliminated && $mark !== null && $mark >= $minimumMark;
                $sources[$unit->code_ue] = [
                    'bulletin_id' => (int) $bulletin->id,
                    'ue_source_id' => (int) $result['ue_id'],
                    'note_sur_20' => $mark,
                    'acquise' => $acquired,
                    'a_reprendre' => ! $acquired,
                ];
                break;
            }
        }

        return array_intersect_key($sources, array_fill_keys($unitCodes, true));
    }

    /** @param array<string, mixed> $snapshot
     * @return array<string, mixed>|null
     */
    private function unitResultFromSnapshot(array $snapshot, string $code): ?array
    {
        $units = $snapshot['ues'] ?? $snapshot['resultats_ue'] ?? $snapshot['resultats'] ?? $snapshot['lignes'] ?? [];
        if (! is_array($units)) {
            return null;
        }

        foreach ($units as $unit) {
            if (is_array($unit) && ($unit['code_ue'] ?? $unit['code'] ?? null) === $code) {
                return $unit;
            }
        }

        return null;
    }

    private function academicSheetPath(object $context): string
    {
        return 'fiches-academiques/'.$context->etudiant_id.'/'.$context->inscription_classe_id.'.pdf';
    }

    private function latestEnrollmentDecision(Request $request, int $semester): ?string
    {
        $notifications = DB::table('gnu.notification')
            ->where('destinataire_id', $request->user()->id)
            ->where('type_notification', 'INSCRIPTION_DECIDEE')
            ->orderByDesc('created_at')->limit(50)->pluck('contenu');

        foreach ($notifications as $content) {
            $data = is_string($content) ? json_decode($content, true) : (array) $content;
            if ((int) ($data['semestre'] ?? 0) === $semester) {
                return $data['message'] ?? null;
            }
        }

        return null;
    }

    private function studentId(Request $request): int
    {
        $id = DB::table('gnu.etudiant')->where('utilisateur_id', $request->user()->id)->value('id');
        abort_unless($id !== null, 404, 'Profil étudiant introuvable.');

        return (int) $id;
    }

    private function syncNotifications(int $userId, int $studentId): void
    {
        $published = DB::table('gnu.publication as p')
            ->join('gnu.inscription_classe as ic', 'ic.classe_id', '=', 'p.classe_id')
            ->join('gnu.etudiant as e', 'e.id', '=', 'ic.etudiant_id')
            ->where('e.id', $studentId)->get(['p.id', 'p.periode', 'p.date_publication']);
        foreach ($published as $item) {
            $this->notify($userId, [
                'type_notification' => 'PUBLICATION',
                'cle_evenement' => 'PUBLICATION|'.$item->id,
                'contenu' => ['titre' => 'Résultats publiés', 'message' => 'Les résultats '.$item->periode.' sont disponibles.', 'periode' => $item->periode],
                'date_envoi' => $item->date_publication,
            ]);
        }

        $decisions = DB::table('gnu.decision_requete as d')
            ->join('gnu.requete as r', 'r.id', '=', 'd.requete_id')
            ->join('gnu.inscription_ue as iu', 'iu.id', '=', 'r.inscription_ue_id')
            ->join('gnu.inscription_classe as ic', 'ic.id', '=', 'iu.inscription_classe_id')
            ->where('ic.etudiant_id', $studentId)->where('d.courante', true)
            ->get(['r.id', 'd.action_decision', 'd.motif', 'd.date_decision']);
        foreach ($decisions as $decision) {
            $this->notify($userId, [
                'type_notification' => 'REQUETE_DECIDEE',
                'cle_evenement' => 'REQUETE|'.$decision->id.'|DECISION',
                'contenu' => ['titre' => 'Réponse à votre requête', 'message' => $decision->motif, 'decision' => $decision->action_decision],
                'date_envoi' => $decision->date_decision,
                'requete_id' => $decision->id,
            ]);
        }

        $sessions = DB::table('gnu.session_rattrapage as s')
            ->join('gnu.inscription_classe as ic', 'ic.classe_id', '=', 's.classe_id')
            ->join('gnu.candidature_rattrapage as cr', function ($join) use ($studentId): void {
                $join->on('cr.session_id', '=', 's.id')->where('cr.etudiant_id', '=', $studentId);
            })
            ->where('ic.etudiant_id', $studentId)->whereIn('s.statut_session', ['PREVUE', 'OUVERTE'])
            ->whereDate('s.date_session', '>=', today())->get(['s.id', 's.libelle', 's.date_session']);
        foreach ($sessions as $session) {
            $this->notify($userId, [
                'type_notification' => 'SESSION_RATTRAPAGE',
                'cle_evenement' => 'RATTRAPAGE|'.$session->id,
                'contenu' => ['titre' => 'Session de rattrapage', 'message' => $session->libelle, 'date' => $session->date_session],
                'date_envoi' => now(),
            ]);
        }

        $evaluations = DB::table('gnu.evaluation as ev')
            ->join('gnu.affectation as a', 'a.id', '=', 'ev.affectation_id')
            ->join('gnu.matiere as m', 'm.id', '=', 'a.matiere_id')
            ->join('gnu.ue as u', 'u.id', '=', 'm.ue_id')
            ->join('gnu.inscription_classe as ic', 'ic.classe_id', '=', 'a.classe_id')
            ->join('gnu.inscription_ue as iu', function ($join): void {
                $join->on('iu.inscription_classe_id', '=', 'ic.id')->on('iu.ue_id', '=', 'u.id');
            })
            ->where('ic.etudiant_id', $studentId)->where('iu.statut_inscription', '!=', 'ANNULEE')->where('a.actif', true)
            ->whereIn('ev.statut_evaluation', ['PREVUE', 'OUVERTE'])
            ->whereDate('ev.date_evaluation', '>=', today())
            ->whereDate('ev.date_evaluation', '<=', today()->addDays(7))
            ->get(['ev.id', 'ev.type_eval', 'ev.date_evaluation', 'u.code_ue']);
        foreach ($evaluations as $evaluation) {
            $this->notify($userId, [
                'type_notification' => 'RAPPEL_NOTES',
                'cle_evenement' => 'EVALUATION|'.$evaluation->id,
                'contenu' => ['titre' => 'Échéance académique à venir', 'message' => $evaluation->type_eval.' · '.$evaluation->code_ue, 'date' => $evaluation->date_evaluation],
                'evaluation_id' => $evaluation->id,
                'jour_ouvrable' => today()->toDateString(),
                'date_envoi' => now(),
            ]);
        }
    }

    /** @param array<string, mixed> $notification */
    private function notify(int $userId, array $notification): void
    {
        DB::select("SELECT set_config('gnu.acteur_id', ?, true), set_config('gnu.motif', ?, true)", [(string) $userId, 'Création d’une notification académique']);
        DB::table('gnu.notification')->insertOrIgnore([
            'destinataire_id' => $userId,
            'evaluation_id' => $notification['evaluation_id'] ?? null,
            'requete_id' => $notification['requete_id'] ?? null,
            'type_notification' => $notification['type_notification'],
            'cle_evenement' => $notification['cle_evenement'],
            'contenu' => json_encode($notification['contenu'], JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE),
            'jour_ouvrable' => $notification['jour_ouvrable'] ?? null,
            'date_envoi' => $notification['date_envoi'] ?? now(),
            'date_lecture' => null,
            'statut_envoi' => 'ENVOYEE',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function setAuditContext(Request $request, string $reason): void
    {
        DB::select("SELECT set_config('gnu.acteur_id', ?, true), set_config('gnu.motif', ?, true)", [(string) $request->user()->id, $reason]);
    }

    /** @param array<string, mixed> $content
     * @return array<string, mixed>
     */
    private function annotateEvaluationTypes(array $content): array
    {
        $units = $content['ues'] ?? [];
        if (! is_array($units)) {
            return $content;
        }

        $evaluationIds = collect($units)
            ->filter(fn (mixed $unit): bool => is_array($unit))
            ->flatMap(fn (array $unit): array => is_array($unit['ecs'] ?? null) ? $unit['ecs'] : [])
            ->filter(fn (mixed $component): bool => is_array($component))
            ->flatMap(fn (array $component): array => is_array($component['sources'] ?? null) ? $component['sources'] : [])
            ->filter(fn (mixed $source): bool => is_array($source))
            ->map(fn (array $source): int => (int) ($source['evaluation_origine_id'] ?? $source['evaluation_id'] ?? 0))
            ->filter(fn (int $id): bool => $id > 0)
            ->unique()
            ->values();
        $types = $evaluationIds->isEmpty()
            ? collect()
            : DB::table('gnu.evaluation')->whereIn('id', $evaluationIds)->pluck('type_eval', 'id');

        foreach ($units as &$unit) {
            if (! is_array($unit) || ! is_array($unit['ecs'] ?? null)) {
                continue;
            }
            foreach ($unit['ecs'] as &$component) {
                if (! is_array($component) || ! is_array($component['sources'] ?? null)) {
                    continue;
                }
                foreach ($component['sources'] as &$source) {
                    if (! is_array($source)) {
                        continue;
                    }
                    $originId = (int) ($source['evaluation_origine_id'] ?? $source['evaluation_id'] ?? 0);
                    $source['type_eval'] = $types->get($originId, 'Évaluation');
                }
                unset($source);
            }
            unset($component);
        }
        unset($unit);
        $content['ues'] = $units;

        return $content;
    }
}
