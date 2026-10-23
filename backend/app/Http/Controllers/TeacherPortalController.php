<?php

namespace App\Http\Controllers;

use App\Services\AcademicRules;
use App\Services\GradeSpreadsheetReader;
use DomainException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpFoundation\File\UploadedFile;

class TeacherPortalController extends Controller
{
    public function assignments(Request $request): JsonResponse
    {
        $teacherId = DB::table('gnu.enseignant')
            ->where('utilisateur_id', $request->user()->id)
            ->value('id');
        abort_unless($teacherId !== null, 404, 'Profil enseignant introuvable.');

        $assignments = DB::table('gnu.affectation as a')
            ->join('gnu.classe as c', 'c.id', '=', 'a.classe_id')
            ->join('gnu.matiere as m', 'm.id', '=', 'a.matiere_id')
            ->join('gnu.ue as u', 'u.id', '=', 'm.ue_id')
            ->join('gnu.annee_academique as an', 'an.id', '=', 'c.annee_id')
            ->where('a.enseignant_id', $teacherId)
            ->where('a.actif', true)
            ->when($request->filled('annee_id'), fn ($query) => $query->where('c.annee_id', $request->integer('annee_id')))
            ->orderByDesc('an.date_debut')
            ->orderBy('c.code_classe')
            ->orderBy('u.code_ue')
            ->orderBy('m.rang_ec')
            ->get([
                'a.id as affectation_id', 'c.id as classe_id', 'c.code_classe',
                'an.libelle as annee_academique', 'u.id as ue_id', 'u.code_ue',
                'u.intitule_ue', 'u.numero_semestre', 'm.id as matiere_id', 'm.code_m', 'm.intitule_matiere',
            ]);

        return response()->json(['data' => $assignments]);
    }

    public function evaluationPlan(Request $request, int $affectation): JsonResponse
    {
        $teacherId = $this->teacherId($request);

        return response()->json(['data' => $this->planData($affectation, $teacherId)]);
    }

    public function proposeEvaluationProfile(Request $request, int $affectation): JsonResponse
    {
        $data = $request->validate(['code_profil' => ['required', 'in:CC_SN,CC_TP_SN,CC_TPE_SN']]);
        $teacherId = $this->teacherId($request);
        $assignment = $this->ownedAssignment($affectation, $teacherId);
        DB::transaction(function () use ($request, $data, $assignment, $teacherId): void {
            $this->setAuditContext($request, 'Proposition de profil de notation détecté dans le fichier de notes');
            DB::table('gnu.proposition_profil_evaluation')->updateOrInsert(
                ['ue_id' => $assignment->ue_id, 'enseignant_id' => $teacherId, 'code_profil' => $data['code_profil'], 'statut' => 'EN_ATTENTE'],
                ['affectation_id' => $assignment->id, 'updated_at' => now(), 'created_at' => now()],
            );
        });

        return response()->json(['message' => 'La proposition de barème a été transmise à la cellule.'], 202);
    }

    public function saveEvaluationPlan(Request $request, int $affectation): JsonResponse
    {
        $data = $this->normalizeOptionalMotif($request->validate([
            'motif' => ['nullable', 'string', 'min:8', 'max:1000'],
            'evaluations' => ['required', 'array', 'min:1', 'max:20'],
            'evaluations.*.evaluation_id' => ['nullable', 'integer', 'min:1', 'distinct'],
            'evaluations.*.type_eval' => ['required', 'in:CC,TP,TPE,SN'],
            'evaluations.*.date_evaluation' => ['required', 'date'],
            'evaluations.*.poids' => ['required', 'numeric', 'gt:0', 'lte:100'],
        ]));
        $teacherId = $this->teacherId($request);
        $assignment = $this->ownedAssignment($affectation, $teacherId);
        abort_if($assignment->profil_evaluation === null, 409, 'Le barème officiel de cette UE doit d’abord être défini par la cellule.');
        $expected = $this->weightsForProfile($assignment->profil_evaluation);
        $received = collect($data['evaluations'])->groupBy('type_eval')->map(fn ($rows) => (float) $rows->sum('poids'))->all();
        foreach (['CC', 'TP', 'TPE', 'SN'] as $type) {
            abort_if(abs((float) ($received[$type] ?? 0) - (float) ($expected[$type] ?? 0)) > 0.0001, 409, 'Les pondérations doivent respecter le profil officiel défini par la cellule.');
        }
        $weights = collect($data['evaluations'])->mapWithKeys(fn (array $row, int $index): array => [(string) $index => (float) $row['poids']])->all();
        try {
            $rules = app(AcademicRules::class);
            $rules->validateEvaluationWeights($weights);
            $rules->validateOfficialEvaluationWeights($data['evaluations']);
        } catch (DomainException $exception) {
            throw ValidationException::withMessages(['evaluations' => [$exception->getMessage()]]);
        }

        $planId = DB::transaction(function () use ($request, $data, $assignment): int {
            DB::table('gnu.affectation')->where('id', $assignment->id)->lockForUpdate()->first();
            $this->setAuditContext($request, $data['motif']);
            $currentPlan = DB::table('gnu.plan_evaluation')->where('affectation_id', $assignment->id)
                ->where('portee', 'CLASSE')->where('statut_plan', 'ACTIF')->orderByDesc('version_plan')->first();
            $retainedEvaluationIds = collect($data['evaluations'])->pluck('evaluation_id')->filter()->map(fn ($id): int => (int) $id)->all();
            if ($currentPlan !== null) {
                $gradedEvaluationIds = DB::table('gnu.ligne_plan as lp')->join('gnu.note as n', 'n.evaluation_id', '=', 'lp.evaluation_id')
                    ->where('lp.plan_id', $currentPlan->id)->distinct()->pluck('lp.evaluation_id')->map(fn ($id): int => (int) $id)->all();
                abort_if(array_diff($gradedEvaluationIds, $retainedEvaluationIds) !== [], 409, 'Une évaluation déjà notée ne peut pas être retirée du barème. Conservez-la dans la nouvelle version.');
                DB::table('gnu.plan_evaluation')->where('id', $currentPlan->id)->update(['statut_plan' => 'ARCHIVE', 'updated_at' => now()]);
            }

            $version = (int) DB::table('gnu.plan_evaluation')->where('affectation_id', $assignment->id)->max('version_plan') + 1;
            $planId = (int) DB::table('gnu.plan_evaluation')->insertGetId([
                'affectation_id' => $assignment->id,
                'version_plan' => $version,
                'statut_plan' => 'BROUILLON',
                'portee' => 'CLASSE',
                'inscription_ue_id' => null,
                'decision_id' => null,
                'plan_commun_id' => null,
                'created_at' => now(),
                'updated_at' => now(),
            ], 'id');

            foreach ($data['evaluations'] as $row) {
                if (! empty($row['evaluation_id'])) {
                    $evaluation = DB::table('gnu.evaluation')->where('id', $row['evaluation_id'])
                        ->where('affectation_id', $assignment->id)->first();
                    abort_unless($evaluation !== null && $evaluation->mode_evaluation === 'NORMALE', 422, 'Évaluation étrangère à cette affectation.');
                    abort_if(DB::table('gnu.note')->where('evaluation_id', $evaluation->id)->exists()
                        && ($evaluation->type_eval !== $row['type_eval'] || Carbon::parse($evaluation->date_evaluation)->toDateString() !== Carbon::parse($row['date_evaluation'])->toDateString()),
                        409, 'Une évaluation déjà notée conserve son type et sa date.');
                    if (! DB::table('gnu.note')->where('evaluation_id', $evaluation->id)->exists()) {
                        DB::table('gnu.evaluation')->where('id', $evaluation->id)->update([
                            'type_eval' => $row['type_eval'],
                            'date_evaluation' => $row['date_evaluation'],
                            'statut_evaluation' => $evaluation->statut_evaluation === 'REALISEE' ? 'REALISEE' : 'PROGRAMMEE',
                            'updated_at' => now(),
                        ]);
                    }
                    $evaluationId = (int) $evaluation->id;
                } else {
                    $evaluationId = (int) DB::table('gnu.evaluation')->insertGetId([
                        'affectation_id' => $assignment->id,
                        'type_eval' => $row['type_eval'],
                        'date_evaluation' => $row['date_evaluation'],
                        'mode_evaluation' => 'NORMALE',
                        'statut_evaluation' => 'PROGRAMMEE',
                        'evaluation_origine_id' => null,
                        'version_calendrier' => 'V1',
                        'created_at' => now(),
                        'updated_at' => now(),
                    ], 'id');
                }

                DB::table('gnu.ligne_plan')->insert([
                    'plan_id' => $planId,
                    'evaluation_id' => $evaluationId,
                    'retenue' => true,
                    'poids_evaluation' => $row['poids'],
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);
            }

            DB::table('gnu.plan_evaluation')->where('id', $planId)->update(['statut_plan' => 'ACTIF', 'updated_at' => now()]);

            return $planId;
        });

        return response()->json(['id' => $planId, 'data' => $this->planData($affectation, $teacherId)], 201);
    }

    public function updateEvaluationStatus(Request $request, int $affectation, int $evaluation): JsonResponse
    {
        $data = $this->normalizeOptionalMotif($request->validate([
            'statut_evaluation' => ['required', 'in:PROGRAMMEE,REALISEE'],
            'motif' => ['nullable', 'string', 'min:8', 'max:1000'],
        ]));
        $teacherId = $this->teacherId($request);
        $this->ownedAssignment($affectation, $teacherId);
        $item = $this->activeEvaluation($affectation, $evaluation);
        abort_if(
            $item->statut_evaluation !== $data['statut_evaluation']
                && DB::table('gnu.note')->where('evaluation_id', $item->id)->exists(),
            409,
            'Le statut ne peut plus changer après la première saisie de note.'
        );

        DB::transaction(function () use ($request, $data, $item): void {
            $this->setAuditContext($request, $data['motif']);
            DB::table('gnu.evaluation')->where('id', $item->id)->update([
                'statut_evaluation' => $data['statut_evaluation'],
                'updated_at' => now(),
            ]);
        });

        return response()->json(['message' => 'Statut de l’évaluation mis à jour.']);
    }

    public function storeRetakeSession(Request $request, int $affectation): JsonResponse
    {
        $data = $request->validate([
            'libelle' => ['required', 'string', 'max:255'],
            'date_session' => ['required', 'date', 'after_or_equal:today'],
        ]);
        $assignment = $this->ownedAssignment($affectation, $this->teacherId($request));
        $id = DB::transaction(function () use ($request, $data, $assignment): int {
            $this->setAuditContext($request, 'Programmation d’une session de rattrapage par l’enseignant');
            $sessionId = (int) DB::table('gnu.session_rattrapage')->insertGetId([
                'classe_id' => $assignment->classe_id,
                'libelle' => trim($data['libelle']),
                'date_session' => $data['date_session'],
                'statut_session' => 'PREVUE',
                'created_at' => now(),
                'updated_at' => now(),
            ], 'id');
            DB::table('gnu.session_rattrapage_ue')->insert([
                'session_id' => $sessionId,
                'ue_id' => $assignment->ue_id,
                'statut_session' => 'PREVUE',
                'created_at' => now(),
                'updated_at' => now(),
            ]);

            return $sessionId;
        });

        return response()->json(['id' => $id, 'message' => 'Session de rattrapage programmée.'], 201);
    }

    public function retakeCandidates(Request $request, int $affectation): JsonResponse
    {
        $assignment = $this->ownedAssignment($affectation, $this->teacherId($request));
        $sessions = DB::table('gnu.session_rattrapage as s')
            ->leftJoin('gnu.session_rattrapage_ue as su', 'su.session_id', '=', 's.id')
            ->where('s.classe_id', $assignment->classe_id)
            ->where(fn ($query) => $query->where('su.ue_id', $assignment->ue_id)->orWhereNull('su.ue_id'))
            ->where('s.statut_session', '<>', 'ANNULEE')
            ->orderByDesc('s.date_session')->get([
                's.id', 's.libelle', 's.date_session', 's.statut_session',
            ])->unique('id')->values();
        $rows = [];
        foreach ($sessions as $session) {
            $candidates = DB::table('gnu.candidature_rattrapage as cr')
                ->join('gnu.inscription_ue as iu', 'iu.id', '=', 'cr.inscription_ue_id')
                ->join('gnu.inscription_classe as ic', 'ic.id', '=', 'iu.inscription_classe_id')
                ->join('gnu.etudiant as e', 'e.id', '=', 'ic.etudiant_id')
                ->join('gnu.utilisateur as u', 'u.id', '=', 'e.utilisateur_id')
                ->where('cr.session_id', $session->id)->where('cr.matiere_id', $assignment->matiere_id)
                ->whereIn('cr.statut_candidature', ['AUTORISEE', 'PROGRAMMEE', 'COMPOSEE', 'ABSENTE'])
                ->orderBy('e.matricule')->get([
                    'cr.id as candidature_id', 'cr.evaluation_origine_id', 'cr.evaluation_rattrapage_id',
                    'cr.statut_candidature', 'cr.date_consommation', 'iu.id as inscription_ue_id',
                    'e.matricule', 'u.nom', 'u.prenom',
                ]);
            $evaluations = [];
            foreach ($candidates->groupBy('evaluation_rattrapage_id') as $evaluationId => $evaluationCandidates) {
                $evaluation = $evaluationId === '' ? null : DB::table('gnu.evaluation')->where('id', (int) $evaluationId)->first();
                $notes = $evaluation === null ? collect() : DB::table('gnu.note')->where('evaluation_id', $evaluation->id)
                    ->whereIn('inscription_ue_id', $evaluationCandidates->pluck('inscription_ue_id'))
                    ->get()->keyBy('inscription_ue_id');
                $transmission = $evaluation === null ? null : DB::table('gnu.transmission_note')->where('evaluation_id', $evaluation->id)->orderByDesc('version')->first(['id', 'version', 'statut']);
                $digitized = $transmission === null ? collect() : DB::table('gnu.note_numerisee')->where('transmission_id', $transmission->id)
                    ->get()->keyBy('inscription_ue_id');
                $evaluations[] = [
                    'evaluation_id' => $evaluation?->id === null ? null : (int) $evaluation->id,
                    'evaluation_origine_id' => (int) $evaluationCandidates->first()->evaluation_origine_id,
                    'statut_evaluation' => $evaluation?->statut_evaluation,
                    'transmission' => $transmission,
                    'etudiants' => $evaluationCandidates->map(function (object $candidate) use ($notes, $digitized): array {
                        $note = $notes->get($candidate->inscription_ue_id);
                        $digitizedNote = $digitized->get($candidate->inscription_ue_id);

                        return [
                            'candidature_id' => (int) $candidate->candidature_id,
                            'inscription_ue_id' => (int) $candidate->inscription_ue_id,
                            'matricule' => $candidate->matricule,
                            'nom' => trim($candidate->prenom.' '.$candidate->nom),
                            'statut_candidature' => $candidate->statut_candidature,
                            'date_consommation' => $candidate->date_consommation,
                            'note_id' => $note?->id === null ? null : (int) $note->id,
                            'version_note' => $note?->version_note === null ? null : (int) $note->version_note,
                            'valeur_note' => $note?->valeur_note,
                            'situation' => $note?->situation ?? 'MANQUANTE',
                            'valeur_numerisee' => $digitizedNote?->valeur_note,
                            'situation_numerisee' => $digitizedNote?->situation,
                        ];
                    })->values()->all(),
                ];
            }
            $rows[] = [
                'id' => (int) $session->id,
                'libelle' => $session->libelle,
                'date_session' => $session->date_session,
                'statut_session' => $session->statut_session,
                'evaluations' => $evaluations,
                'candidatures_en_attente' => $candidates->whereNull('evaluation_rattrapage_id')->count(),
            ];
        }

        return response()->json(['data' => $rows]);
    }

    public function createRetakeEvaluations(Request $request, int $affectation, int $session): JsonResponse
    {
        $assignment = $this->ownedAssignment($affectation, $this->teacherId($request));
        $sessionRow = DB::table('gnu.session_rattrapage as s')->leftJoin('gnu.session_rattrapage_ue as su', 'su.session_id', '=', 's.id')
            ->where('s.id', $session)->where('s.classe_id', $assignment->classe_id)
            ->where(fn ($query) => $query->where('su.ue_id', $assignment->ue_id)->orWhereNull('su.ue_id'))
            ->where('s.statut_session', 'OUVERTE')->first(['s.id', 's.date_session']);
        abort_unless($sessionRow !== null, 404, 'La session ouverte est introuvable pour cette affectation.');
        abort_if($sessionRow->date_session > today()->toDateString(), 409, 'Les notes ne peuvent être saisies qu’après la date de la session.');

        $created = DB::transaction(function () use ($request, $assignment, $sessionRow): array {
            DB::table('gnu.affectation')->where('id', $assignment->id)->lockForUpdate()->first();
            DB::table('gnu.session_rattrapage')->where('id', $sessionRow->id)->lockForUpdate()->first();
            $this->setAuditContext($request, 'Création des évaluations de rattrapage autorisées');
            $candidates = DB::table('gnu.candidature_rattrapage')->where('session_id', $sessionRow->id)
                ->where('matiere_id', $assignment->matiere_id)
                ->whereIn('statut_candidature', ['AUTORISEE', 'PROGRAMMEE'])
                ->lockForUpdate()->get();
            abort_if($candidates->isEmpty(), 422, 'Aucune candidature autorisée ne concerne cette affectation et cette session.');
            $ids = [];
            foreach ($candidates->groupBy('evaluation_origine_id') as $originId => $group) {
                $origin = DB::table('gnu.evaluation')->where('id', $originId)->where('affectation_id', $assignment->id)
                    ->where('mode_evaluation', 'NORMALE')->where('type_eval', 'SN')->first();
                abort_unless($origin !== null, 409, 'L’évaluation SN d’origine n’appartient plus à cette affectation.');
                $existingId = $group->pluck('evaluation_rattrapage_id')->filter()->unique()->first();
                if ($existingId !== null) {
                    abort_if($group->contains(fn (object $candidate): bool => $candidate->evaluation_rattrapage_id !== null && (int) $candidate->evaluation_rattrapage_id !== (int) $existingId), 409, 'Les candidatures de cette session pointent vers plusieurs évaluations.');
                    $evaluationId = (int) $existingId;
                } else {
                    $date = Carbon::parse($sessionRow->date_session)->setTime(9, 0)->utc();
                    $evaluationId = (int) DB::table('gnu.evaluation')->insertGetId([
                        'affectation_id' => $assignment->id,
                        'type_eval' => 'SN',
                        'date_evaluation' => $date,
                        'mode_evaluation' => 'RATTRAPAGE',
                        'statut_evaluation' => 'REALISEE',
                        'evaluation_origine_id' => $origin->id,
                        'version_calendrier' => $origin->version_calendrier,
                        'created_at' => now(),
                        'updated_at' => now(),
                    ], 'id');
                }
                DB::table('gnu.candidature_rattrapage')->where('session_id', $sessionRow->id)
                    ->where('matiere_id', $assignment->matiere_id)->where('evaluation_origine_id', $originId)
                    ->whereIn('statut_candidature', ['AUTORISEE', 'PROGRAMMEE'])
                    ->update(['evaluation_rattrapage_id' => $evaluationId, 'updated_at' => now()]);
                $ids[] = $evaluationId;
            }

            return $ids;
        });

        return response()->json(['evaluation_ids' => $created, 'message' => 'Les épreuves de rattrapage sont prêtes pour la saisie des notes.']);
    }

    public function saveRetakeGrades(Request $request, int $affectation, int $evaluation): JsonResponse
    {
        $data = $this->normalizeOptionalMotif($request->validate([
            'motif' => ['nullable', 'string', 'min:8', 'max:1000'],
            'notes' => ['required', 'array', 'min:1', 'max:500'],
            'notes.*.matricule' => ['required', 'string', 'max:32', 'distinct'],
            'notes.*.situation' => ['required', 'in:NUMERIQUE,ABSENTE'],
            'notes.*.valeur_note' => ['nullable', 'numeric', 'between:0,20'],
            'notes.*.version_note' => ['nullable', 'integer', 'min:1'],
        ]));
        $assignment = $this->ownedAssignment($affectation, $this->teacherId($request));
        $event = DB::table('gnu.evaluation')->where('id', $evaluation)->where('affectation_id', $assignment->id)
            ->where('mode_evaluation', 'RATTRAPAGE')->first();
        abort_unless($event !== null, 404, 'Évaluation de rattrapage introuvable.');
        $students = DB::table('gnu.candidature_rattrapage as cr')->join('gnu.inscription_ue as iu', 'iu.id', '=', 'cr.inscription_ue_id')
            ->join('gnu.inscription_classe as ic', 'ic.id', '=', 'iu.inscription_classe_id')
            ->join('gnu.etudiant as e', 'e.id', '=', 'ic.etudiant_id')
            ->where('cr.evaluation_rattrapage_id', $evaluation)->where('cr.matiere_id', $assignment->matiere_id)
            ->whereIn('cr.statut_candidature', ['AUTORISEE', 'PROGRAMMEE'])
            ->whereNull('cr.date_consommation')->get(['e.matricule', 'cr.inscription_ue_id'])
            ->keyBy(fn (object $row): string => strtoupper(trim($row->matricule)));
        abort_unless($students->count() === count($data['notes']), 422, 'Saisissez une note pour chaque candidat autorisé à cette épreuve.');
        foreach ($data['notes'] as $index => $row) {
            $student = $students->get(strtoupper(trim($row['matricule'])));
            abort_unless($student !== null, 422, 'Cet étudiant ne possède pas de candidature autorisée à cette épreuve.');
            $this->assertGradesEditable($evaluation, (int) $student->inscription_ue_id);
            if ($row['situation'] === 'NUMERIQUE' && (! isset($row['valeur_note']) || ! is_numeric($row['valeur_note']))) {
                throw ValidationException::withMessages(["notes.$index.valeur_note" => ['Une note numérique entre 0 et 20 est obligatoire.']]);
            }
            if ($row['situation'] === 'ABSENTE' && $row['valeur_note'] !== null) {
                throw ValidationException::withMessages(["notes.$index.valeur_note" => ['Une absence ne peut pas porter de valeur numérique.']]);
            }
        }
        $saved = DB::transaction(function () use ($request, $data, $assignment, $students, $evaluation): int {
            DB::table('gnu.affectation')->where('id', $assignment->id)->lockForUpdate()->first();
            $this->setAuditContext($request, $data['motif']);
            $count = 0;
            foreach ($data['notes'] as $row) {
                $student = $students->get(strtoupper(trim($row['matricule'])));
                $this->assertGradesEditable($evaluation, (int) $student->inscription_ue_id);
                $existing = DB::table('gnu.note')->where('evaluation_id', $evaluation)->where('inscription_ue_id', $student->inscription_ue_id)->lockForUpdate()->first();
                $expectedVersion = (int) ($row['version_note'] ?? 0);
                abort_if((int) ($existing->version_note ?? 0) !== $expectedVersion, 409, 'Une note a changé depuis le chargement. Rechargez le carnet de rattrapage.');
                DB::select("SELECT set_config('gnu.origine', ?, true), set_config('gnu.decision_id', '', true)", [$existing === null ? 'SAISIE' : 'CORRECTION']);
                $values = [
                    'valeur_note' => $row['situation'] === 'NUMERIQUE' ? $row['valeur_note'] : null,
                    'situation' => $row['situation'],
                    'statut_note' => 'BROUILLON',
                    'validateur_id' => null,
                    'date_validation' => null,
                    'updated_at' => now(),
                ];
                if ($existing === null) {
                    DB::table('gnu.note')->insert($values + [
                        'evaluation_id' => $evaluation,
                        'inscription_ue_id' => $student->inscription_ue_id,
                        'version_note' => 1,
                        'created_at' => now(),
                    ]);
                } else {
                    DB::table('gnu.note')->where('id', $existing->id)->update($values + ['version_note' => $expectedVersion]);
                }
                $count++;
            }

            return $count;
        });

        return response()->json(['enregistrements' => $saved, 'message' => 'Notes de rattrapage enregistrées en brouillon. Transmettez-les à la cellule pour numérisation et vérification.']);
    }

    public function gradebook(Request $request, int $affectation): JsonResponse
    {
        $teacherId = $this->teacherId($request);
        $assignment = $this->ownedAssignment($affectation, $teacherId);
        $this->ensureOfficialPlan($request, $assignment);
        $plan = $this->planData($affectation, $teacherId);
        $evaluations = collect($plan['composantes']);
        $students = DB::table('gnu.inscription_classe as ic')
            ->join('gnu.etudiant as e', 'e.id', '=', 'ic.etudiant_id')
            ->join('gnu.utilisateur as u', 'u.id', '=', 'e.utilisateur_id')
            ->join('gnu.inscription_ue as iu', function ($join) use ($assignment): void {
                $join->on('iu.inscription_classe_id', '=', 'ic.id')->where('iu.ue_id', '=', $assignment->ue_id);
            })
            ->where('ic.classe_id', $assignment->classe_id)->where('ic.statut_inscription', 'VALIDEE')
            ->where('iu.statut_inscription', 'VALIDEE')->orderBy('e.matricule')
            ->get(['ic.id as inscription_classe_id', 'e.id as etudiant_id', 'iu.id as inscription_ue_id', 'e.matricule', 'u.nom', 'u.prenom']);
        $evaluationIds = $evaluations->pluck('evaluation_id')->map(fn ($id): int => (int) $id)->all();
        $inscriptionIds = $students->pluck('inscription_ue_id')->map(fn ($id): int => (int) $id)->all();
        $notes = ($evaluationIds !== [] && $inscriptionIds !== [])
            ? DB::table('gnu.note')->whereIn('evaluation_id', $evaluationIds)->whereIn('inscription_ue_id', $inscriptionIds)->get()->keyBy(fn (object $note): string => $note->evaluation_id.':'.$note->inscription_ue_id)
            : collect();
        $digitizedNotes = collect();
        if ($evaluationIds !== [] && $inscriptionIds !== []) {
            $latestTransmissions = DB::table('gnu.transmission_note')->select('evaluation_id')->selectRaw('MAX(version) AS version')
                ->whereIn('evaluation_id', $evaluationIds)->groupBy('evaluation_id');
            $digitizedNotes = DB::table('gnu.note_numerisee as nn')
                ->join('gnu.transmission_note as tn', 'tn.id', '=', 'nn.transmission_id')
                ->joinSub($latestTransmissions, 'latest', function ($join): void {
                    $join->on('latest.evaluation_id', '=', 'tn.evaluation_id')->on('latest.version', '=', 'tn.version');
                })
                ->where('tn.statut', 'A_VERIFIER')->whereIn('nn.inscription_ue_id', $inscriptionIds)
                ->get(['nn.evaluation_id', 'nn.inscription_ue_id', 'nn.valeur_note', 'nn.situation'])
                ->keyBy(fn (object $note): string => $note->evaluation_id.':'.$note->inscription_ue_id);
        }
        $authorizedCorrections = ($evaluationIds !== [] && $inscriptionIds !== [])
            ? DB::table('gnu.requete as r')
                ->join('gnu.decision_requete as d', function ($join): void {
                    $join->on('d.requete_id', '=', 'r.id')->where('d.courante', true);
                })
                ->whereIn('r.evaluation_id', $evaluationIds)
                ->whereIn('r.inscription_ue_id', $inscriptionIds)
                ->where('r.type_requete', 'NOTE_MANQUANTE')
                ->where('r.statut_requete', 'EN_TRAITEMENT')
                ->where('d.action_decision', 'AUTORISER_EVALUATION')
                ->get(['r.evaluation_id', 'r.inscription_ue_id'])
                ->mapWithKeys(fn (object $request): array => [
                    $request->evaluation_id.':'.$request->inscription_ue_id => true,
                ])
            : collect();

        $sheetPaths = [];
        foreach ($students as $student) {
            $path = 'fiches-academiques/'.$student->etudiant_id.'/'.$student->inscription_classe_id.'.pdf';
            $sheetPaths[(int) $student->inscription_classe_id] = Storage::disk('local')->exists($path);
        }

        return response()->json(['data' => [
            'affectation_id' => $affectation,
            'profil_evaluation' => $assignment->profil_evaluation,
            'classe' => $assignment->code_classe,
            'code_ue' => $assignment->code_ue,
            'code_matiere' => $assignment->code_m,
            'plan' => $plan,
            'etudiants' => $students->map(function (object $student) use ($evaluations, $notes, $digitizedNotes, $authorizedCorrections, $assignment, $sheetPaths): array {
                $studentNotes = [];
                foreach ($evaluations as $evaluation) {
                    $note = $notes->get($evaluation['evaluation_id'].':'.$student->inscription_ue_id);
                    $digitizedNote = $digitizedNotes->get($evaluation['evaluation_id'].':'.$student->inscription_ue_id);
                    $studentNotes[] = [
                        'evaluation_id' => (int) $evaluation['evaluation_id'],
                        'note_id' => $note?->id === null ? null : (int) $note->id,
                        'version_note' => $note?->version_note === null ? null : (int) $note->version_note,
                        'valeur_note' => $note?->valeur_note,
                        'situation' => $note?->situation ?? 'MANQUANTE',
                        'valeur_numerisee' => $digitizedNote?->valeur_note,
                        'situation_numerisee' => $digitizedNote?->situation,
                        'statut_note' => $note?->statut_note ?? 'ABSENTE',
                        'correction_autorisee' => $authorizedCorrections->has($evaluation['evaluation_id'].':'.$student->inscription_ue_id),
                    ];
                }
                $provisionalEc = null;
                try {
                    $result = DB::selectOne('SELECT gnu.calculer_ec(?, ?) AS contenu', [$student->inscription_ue_id, $assignment->matiere_id]);
                    $provisionalEc = is_string($result->contenu) ? json_decode($result->contenu, true, flags: JSON_THROW_ON_ERROR) : (array) $result->contenu;
                } catch (\Throwable) {
                    $provisionalEc = null;
                }

                return [
                    'inscription_ue_id' => (int) $student->inscription_ue_id,
                    'matricule' => $student->matricule,
                    'nom' => trim($student->prenom.' '.$student->nom),
                    'inscription_classe_id' => (int) $student->inscription_classe_id,
                    'fiche_academique_disponible' => $sheetPaths[(int) $student->inscription_classe_id] ?? false,
                    'notes' => $studentNotes,
                    'resultat_ec_provisoire' => $provisionalEc,
                ];
            })->values(),
        ]]);
    }

    public function downloadAcademicSheet(Request $request, int $affectation, int $inscriptionClasse): mixed
    {
        $assignment = $this->ownedAssignment($affectation, $this->teacherId($request));
        $registration = DB::table('gnu.inscription_classe as ic')
            ->join('gnu.etudiant as e', 'e.id', '=', 'ic.etudiant_id')
            ->where('ic.id', $inscriptionClasse)->where('ic.classe_id', $assignment->classe_id)
            ->where('ic.statut_inscription', 'VALIDEE')
            ->whereExists(function ($query) use ($assignment): void {
                $query->selectRaw('1')->from('gnu.inscription_ue as iu')
                    ->whereColumn('iu.inscription_classe_id', 'ic.id')
                    ->where('iu.ue_id', $assignment->ue_id)->where('iu.statut_inscription', 'VALIDEE');
            })->first(['e.id as etudiant_id', 'ic.id as inscription_classe_id']);
        abort_unless($registration !== null, 404);
        $path = 'fiches-academiques/'.$registration->etudiant_id.'/'.$registration->inscription_classe_id.'.pdf';
        abort_unless(Storage::disk('local')->exists($path), 404, 'Aucune fiche académique importée pour cet étudiant.');

        return Storage::disk('local')->download($path, 'fiche-academique-reference.pdf', [
            'Content-Type' => 'application/pdf',
        ]);
    }

    public function saveGrades(Request $request, int $affectation, int $evaluation): JsonResponse
    {
        $data = $this->normalizeOptionalMotif($request->validate([
            'motif' => ['nullable', 'string', 'min:8', 'max:1000'],
            'notes' => ['required', 'array', 'min:1', 'max:500'],
            'notes.*.matricule' => ['required', 'string', 'max:32', 'distinct'],
            'notes.*.situation' => ['required', 'in:NUMERIQUE,ABSENTE,MANQUANTE'],
            'notes.*.valeur_note' => ['nullable', 'numeric', 'between:0,20'],
            'notes.*.version_note' => ['nullable', 'integer', 'min:1'],
        ]));
        $teacherId = $this->teacherId($request);
        $assignment = $this->ownedAssignment($affectation, $teacherId);
        $event = $this->activeEvaluation($affectation, $evaluation);
        abort_unless($event->mode_evaluation === 'NORMALE', 404, 'Évaluation introuvable.');

        $studentIds = DB::table('gnu.inscription_classe as ic')
            ->join('gnu.etudiant as e', 'e.id', '=', 'ic.etudiant_id')
            ->join('gnu.inscription_ue as iu', function ($join) use ($assignment): void {
                $join->on('iu.inscription_classe_id', '=', 'ic.id')->where('iu.ue_id', '=', $assignment->ue_id);
            })
            ->where('ic.classe_id', $assignment->classe_id)->where('ic.statut_inscription', 'VALIDEE')
            ->where('iu.statut_inscription', 'VALIDEE')->get(['e.matricule', 'iu.id as inscription_ue_id'])->keyBy('matricule');
        foreach ($data['notes'] as $index => $row) {
            if ($row['situation'] === 'NUMERIQUE' && (! isset($row['valeur_note']) || ! is_numeric($row['valeur_note']))) {
                throw ValidationException::withMessages(["notes.$index.valeur_note" => ['Une note numérique est obligatoire pour cette situation.']]);
            }
            if ($row['situation'] !== 'NUMERIQUE' && $row['valeur_note'] !== null) {
                throw ValidationException::withMessages(["notes.$index.valeur_note" => ['Une valeur numérique n’est pas permise pour une absence ou une note manquante.']]);
            }
            abort_unless($studentIds->has($row['matricule']), 422, 'Le matricule '.$row['matricule'].' n’est pas inscrit à cette UE dans cette classe.');
            $this->assertGradesEditable($evaluation, (int) $studentIds[$row['matricule']]->inscription_ue_id);
        }

        $saved = DB::transaction(function () use ($request, $data, $evaluation, $studentIds, $affectation): int {
            DB::table('gnu.affectation')->where('id', $affectation)->lockForUpdate()->first();
            $this->setAuditContext($request, $data['motif']);
            $count = 0;
            foreach ($data['notes'] as $row) {
                $registrationId = (int) $studentIds[$row['matricule']]->inscription_ue_id;
                $this->assertGradesEditable($evaluation, $registrationId);
                $existing = DB::table('gnu.note')->where('evaluation_id', $evaluation)->where('inscription_ue_id', $registrationId)->lockForUpdate()->first();
                $this->assertGradesEditable($evaluation, (int) $student->inscription_ue_id);
                $expectedVersion = (int) ($row['version_note'] ?? 0);
                abort_if((int) ($existing->version_note ?? 0) !== $expectedVersion, 409, 'Une note a changé depuis le chargement. Rechargez le carnet avant de continuer.');
                $correctionDecisionId = $this->authorizedMissingNoteCorrectionDecisionId($evaluation, $registrationId);
                $values = [
                    'valeur_note' => $row['situation'] === 'NUMERIQUE' ? $row['valeur_note'] : null,
                    'situation' => $row['situation'],
                    'statut_note' => 'BROUILLON',
                    'validateur_id' => null,
                    'date_validation' => null,
                    'updated_at' => now(),
                ];
                if ($existing === null) {
                    DB::select("SELECT set_config('gnu.origine', ?, true), set_config('gnu.decision_id', ?, true)", [
                        $correctionDecisionId !== null ? 'CORRECTION' : 'SAISIE',
                        (string) ($correctionDecisionId ?? ''),
                    ]);
                    DB::table('gnu.note')->insert($values + [
                        'evaluation_id' => $evaluation,
                        'inscription_ue_id' => $registrationId,
                        'version_note' => 1,
                        'validateur_id' => null,
                        'date_validation' => null,
                        'created_at' => now(),
                    ]);
                } else {
                    DB::select("SELECT set_config('gnu.origine', ?, true), set_config('gnu.decision_id', ?, true)", [
                        'CORRECTION', (string) ($correctionDecisionId ?? ''),
                    ]);
                    DB::table('gnu.note')->where('id', $existing->id)->update($values + ['version_note' => $expectedVersion]);
                }
                $count++;
            }

            return $count;
        });

        return response()->json(['enregistrements' => $saved, 'message' => 'Notes enregistrées en brouillon.']);
    }

    public function saveStudentGrades(Request $request, int $affectation): JsonResponse
    {
        $data = $this->normalizeOptionalMotif($request->validate([
            'motif' => ['nullable', 'string', 'min:8', 'max:1000'],
            'matricule' => ['required', 'string', 'max:32'],
            'notes' => ['required', 'array', 'min:1', 'max:20'],
            'notes.*.evaluation_id' => ['required', 'integer', 'min:1', 'distinct'],
            'notes.*.situation' => ['required', 'in:NUMERIQUE,ABSENTE,MANQUANTE'],
            'notes.*.valeur_note' => ['nullable', 'numeric', 'between:0,20'],
            'notes.*.version_note' => ['nullable', 'integer', 'min:1'],
        ]));
        $teacherId = $this->teacherId($request);
        $assignment = $this->ownedAssignment($affectation, $teacherId);
        $student = DB::table('gnu.inscription_classe as ic')
            ->join('gnu.etudiant as e', 'e.id', '=', 'ic.etudiant_id')
            ->join('gnu.inscription_ue as iu', function ($join) use ($assignment): void {
                $join->on('iu.inscription_classe_id', '=', 'ic.id')->where('iu.ue_id', '=', $assignment->ue_id);
            })
            ->where('ic.classe_id', $assignment->classe_id)
            ->where('ic.statut_inscription', 'VALIDEE')
            ->where('iu.statut_inscription', 'VALIDEE')
            ->whereRaw('UPPER(TRIM(e.matricule)) = ?', [strtoupper(trim($data['matricule']))])
            ->first(['e.matricule', 'iu.id as inscription_ue_id']);
        abort_unless($student !== null, 422, 'Cet étudiant n’est pas inscrit et validé dans cette UE.');

        foreach ($data['notes'] as $index => $row) {
            if ($row['situation'] === 'NUMERIQUE' && (! isset($row['valeur_note']) || ! is_numeric($row['valeur_note']))) {
                throw ValidationException::withMessages(["notes.$index.valeur_note" => ['Une note entre 0 et 20 est obligatoire pour cette situation.']]);
            }
            if ($row['situation'] !== 'NUMERIQUE' && $row['valeur_note'] !== null) {
                throw ValidationException::withMessages(["notes.$index.valeur_note" => ['Une valeur numérique n’est pas permise pour une absence ou une note manquante.']]);
            }
            $event = $this->activeEvaluation($affectation, (int) $row['evaluation_id']);
            abort_unless($event->mode_evaluation === 'NORMALE', 404, 'Évaluation introuvable.');
            $this->assertGradesEditable((int) $row['evaluation_id'], (int) $student->inscription_ue_id);
        }

        $saved = DB::transaction(function () use ($request, $data, $assignment, $student): int {
            DB::table('gnu.affectation')->where('id', $assignment->id)->lockForUpdate()->first();
            $this->setAuditContext($request, $data['motif']);
            $count = 0;
            foreach ($data['notes'] as $row) {
                $evaluationId = (int) $row['evaluation_id'];
                $this->assertGradesEditable($evaluationId, (int) $student->inscription_ue_id);
                $existing = DB::table('gnu.note')
                    ->where('evaluation_id', $evaluationId)
                    ->where('inscription_ue_id', $student->inscription_ue_id)
                    ->lockForUpdate()
                    ->first();
                $expectedVersion = (int) ($row['version_note'] ?? 0);
                abort_if((int) ($existing->version_note ?? 0) !== $expectedVersion, 409, 'Une note a changé depuis le chargement. Rechargez le carnet avant de continuer.');
                $correctionDecisionId = $this->authorizedMissingNoteCorrectionDecisionId($evaluationId, (int) $student->inscription_ue_id);
                $values = [
                    'valeur_note' => $row['situation'] === 'NUMERIQUE' ? $row['valeur_note'] : null,
                    'situation' => $row['situation'],
                    'statut_note' => 'BROUILLON',
                    'validateur_id' => null,
                    'date_validation' => null,
                    'updated_at' => now(),
                ];
                if ($existing === null) {
                    DB::select("SELECT set_config('gnu.origine', ?, true), set_config('gnu.decision_id', ?, true)", [
                        $correctionDecisionId !== null ? 'CORRECTION' : 'SAISIE',
                        (string) ($correctionDecisionId ?? ''),
                    ]);
                    DB::table('gnu.note')->insert($values + [
                        'evaluation_id' => $evaluationId,
                        'inscription_ue_id' => $student->inscription_ue_id,
                        'version_note' => 1,
                        'created_at' => now(),
                    ]);
                } else {
                    DB::select("SELECT set_config('gnu.origine', ?, true), set_config('gnu.decision_id', ?, true)", [
                        'CORRECTION', (string) ($correctionDecisionId ?? ''),
                    ]);
                    DB::table('gnu.note')->where('id', $existing->id)->update($values + ['version_note' => $expectedVersion]);
                }
                $count++;
            }

            return $count;
        });

        return response()->json(['enregistrements' => $saved, 'message' => 'Notes enregistrées en brouillon.']);
    }

    public function transmitGrades(Request $request, int $affectation, int $evaluation): JsonResponse
    {
        $data = $this->normalizeOptionalMotif($request->validate([
            'motif' => ['nullable', 'string', 'min:8', 'max:1000'],
        ]));
        $teacherId = $this->teacherId($request);
        $assignment = $this->ownedAssignment($affectation, $teacherId);
        $event = DB::table('gnu.evaluation')->where('id', $evaluation)->where('affectation_id', $affectation)->first();
        abort_unless($event !== null, 404, 'Évaluation introuvable.');
        if ($event->mode_evaluation === 'NORMALE') {
            $this->activeEvaluation($affectation, $evaluation);
        } else {
            abort_unless($event->mode_evaluation === 'RATTRAPAGE' && DB::table('gnu.candidature_rattrapage')
                ->where('evaluation_rattrapage_id', $evaluation)->where('matiere_id', $assignment->matiere_id)
                ->whereIn('statut_candidature', ['AUTORISEE', 'PROGRAMMEE'])->exists(), 404, 'Aucune candidature autorisée pour cette évaluation de rattrapage.');
        }

        $transmissionId = DB::transaction(function () use ($request, $data, $evaluation, $affectation, $assignment, $event): int {
            DB::table('gnu.affectation')->where('id', $affectation)->lockForUpdate()->first();
            $current = DB::table('gnu.transmission_note')->where('evaluation_id', $evaluation)->orderByDesc('version')->lockForUpdate()->first();
            $authorizedCorrection = $this->hasPreparedMissingNoteCorrection($evaluation);
            abort_if(
                $current !== null
                    && in_array($current->statut, ['TRANSMISE', 'A_VERIFIER', 'VERIFIEE'], true)
                    && ! ($current->statut === 'VERIFIEE' && $authorizedCorrection),
                409,
                'Cette transmission ne peut pas être retransmise avant un retour à corriger ou une correction de note manquante autorisée.',
            );
            $roster = $event->mode_evaluation === 'RATTRAPAGE'
                ? DB::table('gnu.candidature_rattrapage')->where('evaluation_rattrapage_id', $evaluation)
                    ->where('matiere_id', $assignment->matiere_id)->whereIn('statut_candidature', ['AUTORISEE', 'PROGRAMMEE'])
                    ->whereNull('date_consommation')->pluck('inscription_ue_id')
                : DB::table('gnu.inscription_classe as ic')->join('gnu.inscription_ue as iu', function ($join) use ($assignment): void {
                    $join->on('iu.inscription_classe_id', '=', 'ic.id')->where('iu.ue_id', '=', $assignment->ue_id);
                })->where('ic.classe_id', $assignment->classe_id)->where('ic.statut_inscription', 'VALIDEE')->where('iu.statut_inscription', 'VALIDEE')->pluck('iu.id');
            abort_if($roster->isEmpty(), 409, 'Aucun étudiant inscrit et validé dans cette UE.');
            $completed = DB::table('gnu.note')->where('evaluation_id', $evaluation)->whereIn('inscription_ue_id', $roster)
                ->whereIn('statut_note', ['BROUILLON', 'VALIDEE'])->whereIn('situation', ['NUMERIQUE', 'ABSENTE'])->count();
            abort_unless($completed === $roster->count(), 409, 'Complétez une note ou une absence pour chaque étudiant inscrit ou candidat avant la transmission.');
            $this->setAuditContext($request, $data['motif']);
            DB::table('gnu.evaluation')->where('id', $evaluation)->where('affectation_id', $affectation)->update([
                'statut_evaluation' => 'REALISEE',
                'updated_at' => now(),
            ]);
            DB::select("SELECT set_config('gnu.origine', ?, true), set_config('gnu.decision_id', '', true)", ['TRANSMISSION']);

            return (int) DB::table('gnu.transmission_note')->insertGetId([
                'evaluation_id' => $evaluation,
                'affectation_id' => $affectation,
                'version' => (int) ($current->version ?? 0) + 1,
                'statut' => 'TRANSMISE',
                'enseignant_id' => $assignment->enseignant_id,
                'transmis_par' => $request->user()->id,
                'transmis_le' => now(),
                'motif' => trim($data['motif']),
                'created_at' => now(),
                'updated_at' => now(),
            ], 'id');
        });

        return response()->json(['id' => $transmissionId, 'transmises' => true, 'message' => 'Notes transmises à la cellule informatique pour contrôle.']);
    }

    public function removeGrade(Request $request, int $affectation, int $note): JsonResponse
    {
        $data = $this->normalizeOptionalMotif($request->validate([
            'motif' => ['nullable', 'string', 'min:8', 'max:1000'],
            'version_note' => ['required', 'integer', 'min:1'],
        ]));
        $teacherId = $this->teacherId($request);
        $this->ownedAssignment($affectation, $teacherId);
        $row = DB::table('gnu.note as n')->join('gnu.evaluation as ev', 'ev.id', '=', 'n.evaluation_id')
            ->where('n.id', $note)->where('ev.affectation_id', $affectation)->first(['n.*']);
        abort_unless($row !== null, 404, 'Note introuvable dans cette affectation.');
        $this->activeEvaluation($affectation, (int) $row->evaluation_id);
        $this->assertGradesEditable((int) $row->evaluation_id);
        abort_if((int) $row->version_note !== (int) $data['version_note'], 409, 'La note a changé. Rechargez le carnet.');

        DB::transaction(function () use ($request, $data, $row, $affectation): void {
            DB::table('gnu.affectation')->where('id', $affectation)->lockForUpdate()->first();
            $this->assertGradesEditable((int) $row->evaluation_id);
            $this->setAuditContext($request, $data['motif']);
            DB::select("SELECT set_config('gnu.origine', ?, true), set_config('gnu.decision_id', '', true)", ['RETRAIT_LOGIQUE']);
            DB::table('gnu.note')->where('id', $row->id)->update([
                'valeur_note' => null,
                'situation' => 'MANQUANTE',
                'statut_note' => 'BROUILLON',
                'validateur_id' => null,
                'date_validation' => null,
                'version_note' => $row->version_note,
                'updated_at' => now(),
            ]);
        });

        return response()->json(['message' => 'Note retirée du calcul. Sa trace reste conservée dans l’historique.']);
    }

    public function importGrades(Request $request, int $affectation, int $evaluation): JsonResponse
    {
        $request->validate(['fichier' => ['required', 'file', 'mimes:xlsx,csv,txt', 'max:10240']]);
        $teacherId = $this->teacherId($request);
        $assignment = $this->ownedAssignment($affectation, $teacherId);
        $event = $this->activeEvaluation($affectation, $evaluation);
        $this->assertGradesEditable($evaluation);
        /** @var UploadedFile $file */
        $file = $request->file('fichier');
        $parsed = app(GradeSpreadsheetReader::class)->read($file);
        $students = DB::table('gnu.inscription_classe as ic')
            ->join('gnu.etudiant as e', 'e.id', '=', 'ic.etudiant_id')
            ->join('gnu.inscription_ue as iu', function ($join) use ($assignment): void {
                $join->on('iu.inscription_classe_id', '=', 'ic.id')->where('iu.ue_id', '=', $assignment->ue_id);
            })
            ->leftJoin('gnu.note as n', function ($join) use ($evaluation): void {
                $join->on('n.inscription_ue_id', '=', 'iu.id')->where('n.evaluation_id', '=', $evaluation);
            })
            ->where('ic.classe_id', $assignment->classe_id)->where('ic.statut_inscription', 'VALIDEE')
            ->where('iu.statut_inscription', 'VALIDEE')->get(['e.matricule', 'iu.id as inscription_ue_id', 'n.version_note'])->keyBy('matricule');
        $seen = [];
        $rows = [];
        $errors = [];
        foreach ($parsed as $index => $item) {
            $line = $index + 2;
            $matricule = strtoupper(trim((string) ($item['matricule'] ?? '')));
            $raw = trim((string) ($item['note'] ?? ''));
            $declaredSituation = mb_strtoupper(trim((string) ($item['situation'] ?? '')));
            if ($matricule === '' || ! $students->has($matricule)) {
                $errors[] = ['ligne' => $line, 'message' => 'Matricule manquant ou non inscrit dans cette classe.'];

                continue;
            }
            if (isset($seen[$matricule])) {
                $errors[] = ['ligne' => $line, 'message' => 'Matricule présent plusieurs fois.'];

                continue;
            }
            $seen[$matricule] = true;
            $situation = match ($declaredSituation) {
                'NUMERIQUE' => 'NUMERIQUE',
                'ABS', 'ABSENT', 'ABSENTE' => 'ABSENTE',
                'MANQUANTE', 'MANQUANT' => 'MANQUANTE',
                '' => match (mb_strtoupper($raw)) {
                    'ABS', 'ABSENT', 'ABSENTE' => 'ABSENTE',
                    '', 'MANQUANTE', 'MANQUANT' => 'MANQUANTE',
                    default => 'NUMERIQUE',
                },
                default => null,
            };
            if ($situation === null) {
                $errors[] = ['ligne' => $line, 'message' => 'La situation doit être NUMERIQUE, ABSENTE ou MANQUANTE.'];

                continue;
            }
            $value = $situation === 'NUMERIQUE' ? str_replace(',', '.', $raw) : null;
            if ($situation === 'NUMERIQUE' && (! is_numeric($value) || (float) $value < 0 || (float) $value > 20)) {
                $errors[] = ['ligne' => $line, 'message' => 'La note doit être comprise entre 0 et 20, ou indiquée ABS/MANQUANTE.'];

                continue;
            }
            $student = $students[$matricule];
            $rows[] = [
                'matricule' => $matricule,
                'situation' => $situation,
                'valeur_note' => $value === null ? null : (float) $value,
                'version_note' => $student->version_note === null ? null : (int) $student->version_note,
            ];
        }

        return response()->json(['data' => ['notes' => $rows, 'erreurs' => $errors, 'importables' => count($rows), 'total' => count($parsed)]]);
    }

    public function previewGradebookImport(Request $request, int $affectation): JsonResponse
    {
        $request->validate(['fichier' => ['required', 'file', 'mimes:xlsx,csv,txt', 'max:10240']]);
        $teacherId = $this->teacherId($request);
        $assignment = $this->ownedAssignment($affectation, $teacherId);
        $table = app(GradeSpreadsheetReader::class)->readTable($request->file('fichier'));
        $matriculeIndex = array_search('matricule', $table['headers'], true);
        if ($matriculeIndex === false) {
            foreach ($table['headers'] as $index => $header) {
                if (str_contains($header, 'matricule')) {
                    $matriculeIndex = $index;
                    break;
                }
            }
        }
        if ($matriculeIndex === false) {
            throw ValidationException::withMessages(['fichier' => ['Le fichier doit contenir une colonne Matricule.']]);
        }

        $columns = [];
        foreach ($table['headers'] as $index => $header) {
            $candidate = preg_replace('/_(?:sur_)?20$/', '', $header) ?? $header;
            if (preg_match('/^(?:note_)?(cc|tp|tpe|sn)(?:_\d+)?$/', $candidate, $matches) === 1) {
                $columns[] = ['index' => $index, 'type_eval' => strtoupper($matches[1]), 'entete' => $header];
            }
        }
        if ($columns === []) {
            throw ValidationException::withMessages(['fichier' => ['Aucune colonne de note CC, TP, TPE ou SN n’a été reconnue.']]);
        }

        $roster = DB::table('gnu.inscription_classe as ic')
            ->join('gnu.etudiant as e', 'e.id', '=', 'ic.etudiant_id')
            ->join('gnu.inscription_ue as iu', function ($join) use ($assignment): void {
                $join->on('iu.inscription_classe_id', '=', 'ic.id')->where('iu.ue_id', '=', $assignment->ue_id);
            })
            ->where('ic.classe_id', $assignment->classe_id)
            ->where('ic.statut_inscription', 'VALIDEE')
            ->where('iu.statut_inscription', 'VALIDEE')
            ->pluck('e.matricule')
            ->map(fn (string $matricule): string => strtoupper(trim($matricule)))
            ->flip();

        $importable = [];
        $errors = [];
        $seen = [];
        foreach ($table['rows'] as $index => $row) {
            $line = $index + 2;
            $matricule = strtoupper(trim((string) ($row[$matriculeIndex] ?? '')));
            if ($matricule === '' || ! $roster->has($matricule)) {
                $errors[] = ['ligne' => $line, 'message' => 'Matricule absent ou non inscrit dans cette UE.'];

                continue;
            }
            if (isset($seen[$matricule])) {
                $errors[] = ['ligne' => $line, 'message' => 'Matricule présent plusieurs fois dans le fichier.'];

                continue;
            }
            $seen[$matricule] = true;
            $marks = [];
            $rowValid = true;
            foreach ($columns as $column) {
                $raw = trim((string) ($row[$column['index']] ?? ''));
                if ($raw === '') {
                    continue;
                }
                $token = mb_strtoupper($raw);
                if (in_array($token, ['ABS', 'ABSENT', 'ABSENTE'], true)) {
                    $marks[] = $column + ['situation' => 'ABSENTE', 'valeur_note' => null];

                    continue;
                }
                $value = str_replace(',', '.', $raw);
                if (! is_numeric($value) || (float) $value < 0 || (float) $value > 20) {
                    $errors[] = ['ligne' => $line, 'message' => 'La note '.$column['entete'].' doit être comprise entre 0 et 20, ou indiquée ABS.'];
                    $rowValid = false;

                    continue;
                }
                $marks[] = $column + ['situation' => 'NUMERIQUE', 'valeur_note' => (float) $value];
            }
            if ($rowValid && $marks !== []) {
                $importable[] = ['matricule' => $matricule, 'notes' => $marks];
            }
        }

        $types = array_values(array_unique(array_column($columns, 'type_eval')));
        $weights = match (true) {
            count($types) === 2 && in_array('CC', $types, true) && in_array('SN', $types, true) => ['CC' => 30, 'SN' => 70],
            count($types) === 3 && in_array('CC', $types, true) && in_array('TP', $types, true) && in_array('SN', $types, true) => ['CC' => 20, 'TP' => 30, 'SN' => 50],
            count($types) === 3 && in_array('CC', $types, true) && in_array('TPE', $types, true) && in_array('SN', $types, true) => ['CC' => 20, 'TPE' => 20, 'SN' => 60],
            default => null,
        };

        return response()->json(['data' => [
            'colonnes' => $columns,
            'notes' => $importable,
            'erreurs' => $errors,
            'importables' => count($importable),
            'total' => count($table['rows']),
            'ponderations' => $weights,
        ]]);
    }

    public function provisionalBulletins(Request $request, int $affectation): JsonResponse
    {
        $teacherId = $this->teacherId($request);
        $assignment = $this->ownedAssignment($affectation, $teacherId);
        $period = $request->query('periode');
        abort_unless(in_array($period, ['S1', 'S2', 'ANNUELLE'], true), 422, 'Période invalide.');
        $semester = (int) DB::table('gnu.ue')->where('id', $assignment->ue_id)->value('numero_semestre');
        abort_unless($period === 'ANNUELLE' || ($period === 'S1' && $semester === 1) || ($period === 'S2' && $semester === 2), 422, 'La période choisie ne correspond pas au semestre de cette UE.');
        $students = DB::table('gnu.inscription_classe as ic')
            ->join('gnu.etudiant as e', 'e.id', '=', 'ic.etudiant_id')
            ->join('gnu.utilisateur as u', 'u.id', '=', 'e.utilisateur_id')
            ->join('gnu.inscription_ue as iu', function ($join) use ($assignment): void {
                $join->on('iu.inscription_classe_id', '=', 'ic.id')->where('iu.ue_id', '=', $assignment->ue_id);
            })
            ->where('ic.classe_id', $assignment->classe_id)->where('ic.statut_inscription', 'VALIDEE')
            ->where('iu.statut_inscription', 'VALIDEE')->orderBy('e.matricule')
            ->get(['iu.id as inscription_ue_id', 'e.matricule', 'u.nom', 'u.prenom']);
        $rows = $students->map(function (object $student) use ($assignment): array {
            $result = DB::selectOne('SELECT gnu.calculer_ec(?, ?) AS contenu', [$student->inscription_ue_id, $assignment->matiere_id]);
            $content = is_string($result->contenu) ? json_decode($result->contenu, true, flags: JSON_THROW_ON_ERROR) : (array) $result->contenu;

            return ['matricule' => $student->matricule, 'nom' => trim($student->prenom.' '.$student->nom), 'resultat_ec_provisoire' => $content];
        });

        return response()->json(['data' => ['classe' => $assignment->code_classe, 'code_matiere' => $assignment->code_m, 'periode' => $period, 'statut' => 'PROVISOIRE', 'etudiants' => $rows]]);
    }

    public function requests(Request $request): JsonResponse
    {
        $teacherId = DB::table('gnu.enseignant')->where('utilisateur_id', $request->user()->id)->value('id');
        abort_unless($teacherId !== null, 404, 'Profil enseignant introuvable.');
        $decisions = DB::table('gnu.decision_requete')->where('courante', true)
            ->select('requete_id', 'action_decision', 'motif as decision_motif');
        $rows = DB::table('gnu.agent_requete_transmission as tr')
            ->join('gnu.requete as r', 'r.id', '=', 'tr.requete_id')
            ->leftJoinSub($decisions, 'd', 'd.requete_id', '=', 'r.id')
            ->join('gnu.inscription_ue as iu', 'iu.id', '=', 'r.inscription_ue_id')
            ->join('gnu.inscription_classe as ic', 'ic.id', '=', 'iu.inscription_classe_id')
            ->join('gnu.classe as c', 'c.id', '=', 'ic.classe_id')
            ->join('gnu.etudiant as e', 'e.id', '=', 'ic.etudiant_id')
            ->join('gnu.utilisateur as student', 'student.id', '=', 'e.utilisateur_id')
            ->join('gnu.ue as ue', 'ue.id', '=', 'iu.ue_id')
            ->join('gnu.matiere as m', 'm.id', '=', 'r.matiere_id')
            ->leftJoin('gnu.requete_rattrapage as rr', 'rr.requete_id', '=', 'r.id')
            ->leftJoin('gnu.session_rattrapage as rs', 'rs.id', '=', 'rr.session_id')
            ->join('gnu.affectation as a', function ($join): void {
                $join->on('a.enseignant_id', '=', 'tr.enseignant_id')
                    ->on('a.classe_id', '=', 'ic.classe_id')
                    ->on('a.matiere_id', '=', 'r.matiere_id')
                    ->where('a.actif', true);
            })
            ->leftJoin('gnu.evaluation as ev', function ($join): void {
                $join->on('ev.id', '=', 'r.evaluation_id')->on('ev.affectation_id', '=', 'a.id');
            })
            ->where('tr.enseignant_id', $teacherId)->where('tr.courante', true)
            ->whereIn('r.statut_requete', ['SOUMISE', 'EN_TRAITEMENT'])->orderBy('r.date_soumission')
            ->get([
                'r.id', 'r.objet', 'r.description', 'r.type_requete', 'r.evaluation_id', 'r.date_soumission', 'd.action_decision', 'd.decision_motif',
                'e.matricule', 'student.nom', 'student.prenom', 'ue.code_ue', 'c.code_classe',
                'm.code_m', 'a.id as affectation_id', 'ue.numero_semestre', 'ev.type_eval', 'ev.date_evaluation',
                'tr.motif as motif_transmission', 'rs.id as session_rattrapage_id',
                'rs.libelle as session_rattrapage', 'rs.date_session as date_session_rattrapage',
            ]);

        return response()->json(['data' => $rows]);
    }

    public function decideRequest(Request $request, int $requete): JsonResponse
    {
        $data = $this->normalizeOptionalMotif($request->validate([
            'decision' => ['required', 'in:ACCEPTER,REFUSER,AUTORISER_EVALUATION,REJETER'],
            'motif' => ['nullable', 'string', 'min:8', 'max:1000'],
        ]));
        $decision = match ($data['decision']) {
            'ACCEPTER', 'AUTORISER_EVALUATION' => 'AUTORISER_EVALUATION',
            default => 'REJETER',
        };
        $teacher = DB::table('gnu.enseignant')->where('utilisateur_id', $request->user()->id)->first(['id']);
        abort_unless($teacher !== null, 404, 'Profil enseignant introuvable.');
        $item = DB::table('gnu.agent_requete_transmission as tr')
            ->join('gnu.requete as r', 'r.id', '=', 'tr.requete_id')
            ->join('gnu.inscription_ue as iu', 'iu.id', '=', 'r.inscription_ue_id')
            ->join('gnu.inscription_classe as ic', 'ic.id', '=', 'iu.inscription_classe_id')
            ->join('gnu.classe as c', 'c.id', '=', 'ic.classe_id')
            ->join('gnu.affectation as a', function ($join): void {
                $join->on('a.classe_id', '=', 'ic.classe_id')->on('a.matiere_id', '=', 'r.matiere_id')->where('a.actif', true);
            })
            ->join('gnu.matiere as m', function ($join): void {
                $join->on('m.id', '=', 'a.matiere_id')->on('m.ue_id', '=', 'iu.ue_id');
            })
            ->leftJoin('gnu.requete_rattrapage as rr', 'rr.requete_id', '=', 'r.id')
            ->leftJoin('gnu.evaluation as ev', function ($join): void {
                $join->on('ev.id', '=', 'r.evaluation_id')->on('ev.affectation_id', '=', 'a.id');
            })
            ->where('r.id', $requete)->where('tr.enseignant_id', $teacher->id)
            ->where('tr.courante', true)->where('a.enseignant_id', $teacher->id)
            ->whereIn('r.statut_requete', ['SOUMISE', 'EN_TRAITEMENT'])->first([
                'r.id', 'r.inscription_ue_id', 'r.matiere_id', 'r.type_requete', 'r.evaluation_id', 'ic.etudiant_id',
                'c.annee_id', 'c.niveau_id', 'm.code_m', 'rr.session_id', 'rr.bulletin_source_id',
                'ev.id as evaluation_valide_id',
            ]);
        abort_unless($item !== null, 404, 'Requête non affectée à cet enseignant ou déjà décidée.');
        $keepInProgress = $item->type_requete === 'NOTE_MANQUANTE' && $decision === 'AUTORISER_EVALUATION';
        abort_if($keepInProgress && ($item->evaluation_id === null || $item->evaluation_valide_id === null), 409, 'La requête ne référence pas une évaluation valide de cette affectation.');
        $isRetakeApplication = $item->type_requete === 'CANDIDATURE_RATTRAPAGE';
        abort_if($isRetakeApplication && ($item->evaluation_id === null || $item->session_id === null || $item->bulletin_source_id === null), 409, 'La demande de rattrapage ne référence pas sa session, son bulletin ou son évaluation d’origine.');
        $decisionId = DB::transaction(function () use ($request, $data, $decision, $item, $teacher, $keepInProgress, $isRetakeApplication): int {
            DB::select("SELECT set_config('gnu.acteur_id', ?, true), set_config('gnu.motif', ?, true)", [(string) $request->user()->id, $data['motif']]);
            $lockedStatus = DB::table('gnu.requete')->where('id', $item->id)->lockForUpdate()->value('statut_requete');
            abort_unless(in_array($lockedStatus, ['SOUMISE', 'EN_TRAITEMENT'], true), 409, 'Cette requête est déjà décidée.');
            abort_if(DB::table('gnu.decision_requete')->where('requete_id', $item->id)->where('courante', true)->where('action_decision', 'AUTORISER_EVALUATION')->exists(), 409, 'Cette requête a déjà été autorisée.');
            $version = (int) DB::table('gnu.decision_requete')->where('requete_id', $item->id)->max('version_decision') + 1;
            DB::table('gnu.decision_requete')->where('requete_id', $item->id)->where('courante', true)
                ->update(['courante' => false, 'updated_at' => now()]);
            $id = (int) DB::table('gnu.decision_requete')->insertGetId([
                'requete_id' => $item->id,
                'enseignant_id' => $teacher->id,
                'version_decision' => $version,
                'action_decision' => $decision,
                'motif' => $data['motif'],
                'courante' => true,
                'created_at' => now(),
                'updated_at' => now(),
            ], 'id');
            DB::select("SELECT set_config('gnu.origine', ?, true), set_config('gnu.decision_id', ?, true)", ['DECISION_REQUETE', (string) $id]);
            DB::table('gnu.requete')->where('id', $item->id)->update([
                'statut_requete' => $keepInProgress ? 'EN_TRAITEMENT' : 'DECIDEE',
                'updated_at' => now(),
            ]);
            if ($isRetakeApplication && $decision === 'AUTORISER_EVALUATION') {
                $session = DB::table('gnu.session_rattrapage')->where('id', $item->session_id)->lockForUpdate()->first();
                abort_unless($session?->statut_session === 'OUVERTE' && $session->date_session >= today()->toDateString(), 409, 'La session a été fermée ou sa date est dépassée; la candidature n’a pas été autorisée.');

                $candidate = DB::table('gnu.candidature_rattrapage')
                    ->where('etudiant_id', $item->etudiant_id)
                    ->where('annee_id', $item->annee_id)
                    ->where('niveau_id', $item->niveau_id)
                    ->where('code_m_scope', $item->code_m)
                    ->lockForUpdate()->first();
                if ($candidate !== null) {
                    abort_unless(
                        (int) $candidate->inscription_ue_id === (int) $item->inscription_ue_id
                            && (int) $candidate->matiere_id === (int) $item->matiere_id
                            && (int) $candidate->bulletin_source_id === (int) $item->bulletin_source_id
                            && (int) $candidate->evaluation_origine_id === (int) $item->evaluation_id,
                        409,
                        'La candidature existante ne correspond pas au bulletin et à l’évaluation de cette demande.'
                    );
                    abort_unless(
                        $candidate->statut_candidature === 'ANNULEE'
                            || $candidate->session_id === null
                            || (int) $candidate->session_id === (int) $session->id,
                        409,
                        'Une candidature existe déjà pour cet EC dans une autre session.'
                    );
                    abort_if(in_array($candidate->statut_candidature, ['COMPOSEE', 'ABSENTE'], true), 409, 'Une session a déjà été consommée pour cet EC.');
                    DB::table('gnu.candidature_rattrapage')->where('id', $candidate->id)->update([
                        'session_id' => $session->id,
                        'evaluation_rattrapage_id' => null,
                        'autorisation_id' => $id,
                        'statut_candidature' => 'PROGRAMMEE',
                        'updated_at' => now(),
                    ]);
                } else {
                    DB::table('gnu.candidature_rattrapage')->insert([
                        'session_id' => $session->id,
                        'inscription_ue_id' => $item->inscription_ue_id,
                        'matiere_id' => $item->matiere_id,
                        'etudiant_id' => $item->etudiant_id,
                        'annee_id' => $item->annee_id,
                        'niveau_id' => $item->niveau_id,
                        'code_m_scope' => $item->code_m,
                        'bulletin_source_id' => $item->bulletin_source_id,
                        'evaluation_origine_id' => $item->evaluation_id,
                        'evaluation_rattrapage_id' => null,
                        'autorisation_id' => $id,
                        'statut_candidature' => 'PROGRAMMEE',
                        'date_consommation' => null,
                        'created_at' => now(),
                        'updated_at' => now(),
                    ]);
                }
            }
            if (! $keepInProgress) {
                DB::table('gnu.agent_requete_transmission')->where('requete_id', $item->id)->where('courante', true)
                    ->update(['courante' => false, 'updated_at' => now()]);
            }
            DB::table('gnu.notification')->insertOrIgnore([
                'destinataire_id' => DB::table('gnu.etudiant')->where('id', $item->etudiant_id)->value('utilisateur_id'),
                'requete_id' => $item->id,
                'type_notification' => 'REQUETE_DECIDEE',
                'cle_evenement' => 'REQUETE|'.$item->id.'|DECISION|V'.$version,
                'contenu' => json_encode([
                    'titre' => 'Réponse à votre requête',
                    'message' => $keepInProgress
                        ? 'La correction est autorisée. L’enseignant va compléter le carnet, puis la note repassera par le contrôle et la vérification.'
                        : ($isRetakeApplication && $decision === 'AUTORISER_EVALUATION'
                            ? 'Votre candidature au rattrapage a été autorisée et votre place est enregistrée pour la session choisie.'
                            : ($data['motif'] ?? 'Votre requête a été rejetée.')),
                    'decision' => $decision,
                ], JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE),
                'date_envoi' => now(),
                'statut_envoi' => 'ENVOYEE',
                'created_at' => now(),
                'updated_at' => now(),
            ]);

            return $id;
        });

        return response()->json(['id' => $decisionId, 'message' => 'Décision transmise à l’étudiant.']);
    }

    private function teacherId(Request $request): int
    {
        $teacherId = DB::table('gnu.enseignant')->where('utilisateur_id', $request->user()->id)->value('id');
        abort_unless($teacherId !== null, 404, 'Profil enseignant introuvable.');

        return (int) $teacherId;
    }

    private function activeEvaluation(int $affectation, int $evaluation): object
    {
        $item = DB::table('gnu.evaluation as ev')
            ->join('gnu.ligne_plan as lp', 'lp.evaluation_id', '=', 'ev.id')
            ->join('gnu.plan_evaluation as pe', 'pe.id', '=', 'lp.plan_id')
            ->where('ev.id', $evaluation)
            ->where('ev.affectation_id', $affectation)
            ->where('pe.affectation_id', $affectation)
            ->where('pe.portee', 'CLASSE')
            ->where('pe.statut_plan', 'ACTIF')
            ->where('lp.retenue', true)
            ->first(['ev.*']);
        abort_unless($item !== null, 404, 'Évaluation absente du plan actif de cette affectation.');

        return $item;
    }

    private function ownedAssignment(int $affectation, int $teacherId): object
    {
        $assignment = DB::table('gnu.affectation as a')
            ->join('gnu.classe as c', 'c.id', '=', 'a.classe_id')
            ->join('gnu.matiere as m', 'm.id', '=', 'a.matiere_id')
            ->join('gnu.ue as u', 'u.id', '=', 'm.ue_id')
            ->leftJoin('gnu.profil_evaluation_ue as profil', 'profil.ue_id', '=', 'u.id')
            ->where('a.id', $affectation)->where('a.enseignant_id', $teacherId)->where('a.actif', true)
            ->first(['a.id', 'a.classe_id', 'a.matiere_id', 'a.enseignant_id', 'u.id as ue_id', 'u.code_ue', 'm.code_m', 'c.code_classe', 'profil.code_profil as profil_evaluation']);
        abort_unless($assignment !== null, 404, 'Affectation introuvable ou inactive.');

        return $assignment;
    }

    /** Create a class plan from the agent-approved UE profile, never from a teacher-side default. */
    private function ensureOfficialPlan(Request $request, object $assignment): void
    {
        if ($assignment->profil_evaluation === null) {
            return;
        }
        DB::transaction(function () use ($request, $assignment): void {
            DB::table('gnu.affectation')->where('id', $assignment->id)->lockForUpdate()->first();
            $activePlan = DB::table('gnu.plan_evaluation')->where('affectation_id', $assignment->id)
                ->where('portee', 'CLASSE')->where('statut_plan', 'ACTIF')->orderByDesc('version_plan')->first();
            $this->setAuditContext($request, 'Initialisation du carnet à partir du profil officiel de l’UE');
            $weights = $this->weightsForProfile($assignment->profil_evaluation);
            if ($activePlan !== null) {
                $currentWeights = DB::table('gnu.ligne_plan as lp')->join('gnu.evaluation as ev', 'ev.id', '=', 'lp.evaluation_id')
                    ->where('lp.plan_id', $activePlan->id)->where('lp.retenue', true)->get(['ev.type_eval', 'lp.poids_evaluation'])
                    ->groupBy('type_eval')->map(fn ($rows) => (float) $rows->sum('poids_evaluation'))->all();
                $matchesProfile = true;
                foreach (['CC', 'TP', 'TPE', 'SN'] as $type) {
                    if (abs((float) ($currentWeights[$type] ?? 0) - (float) ($weights[$type] ?? 0)) > 0.0001) {
                        $matchesProfile = false;
                        break;
                    }
                }
                if ($matchesProfile) {
                    return;
                }
                $hasGrades = DB::table('gnu.ligne_plan as lp')->join('gnu.note as n', 'n.evaluation_id', '=', 'lp.evaluation_id')
                    ->where('lp.plan_id', $activePlan->id)->exists();
                abort_if($hasGrades, 409, 'Le plan de cette affectation ne correspond pas au profil officiel. Contactez la cellule avant toute saisie.');
                DB::table('gnu.plan_evaluation')->where('id', $activePlan->id)->update(['statut_plan' => 'ARCHIVE', 'updated_at' => now()]);
            }
            $version = (int) DB::table('gnu.plan_evaluation')->where('affectation_id', $assignment->id)->max('version_plan') + 1;
            $planId = (int) DB::table('gnu.plan_evaluation')->insertGetId([
                'affectation_id' => $assignment->id, 'version_plan' => $version, 'statut_plan' => 'BROUILLON',
                'portee' => 'CLASSE', 'inscription_ue_id' => null, 'decision_id' => null, 'plan_commun_id' => null,
                'created_at' => now(), 'updated_at' => now(),
            ], 'id');
            foreach ($weights as $type => $weight) {
                $evaluationId = (int) DB::table('gnu.evaluation')->insertGetId([
                    'affectation_id' => $assignment->id, 'type_eval' => $type, 'date_evaluation' => now()->toDateString(),
                    'mode_evaluation' => 'NORMALE', 'statut_evaluation' => 'PROGRAMMEE', 'evaluation_origine_id' => null,
                    'version_calendrier' => 'V1', 'created_at' => now(), 'updated_at' => now(),
                ], 'id');
                DB::table('gnu.ligne_plan')->insert([
                    'plan_id' => $planId, 'evaluation_id' => $evaluationId, 'retenue' => true,
                    'poids_evaluation' => $weight, 'created_at' => now(), 'updated_at' => now(),
                ]);
            }
            DB::table('gnu.plan_evaluation')->where('id', $planId)->update(['statut_plan' => 'ACTIF', 'updated_at' => now()]);
        });
    }

    /** @return array<string, float> */
    private function weightsForProfile(string $profile): array
    {
        return match ($profile) {
            'CC_SN' => ['CC' => 30.0, 'SN' => 70.0],
            'CC_TP_SN' => ['CC' => 20.0, 'TP' => 30.0, 'SN' => 50.0],
            'CC_TPE_SN' => ['CC' => 20.0, 'TPE' => 20.0, 'SN' => 60.0],
            default => [],
        };
    }

    /** @return array<string, mixed> */
    public function decideTransmission(Request $request, int $transmission): JsonResponse
    {
        $data = $this->normalizeOptionalMotif($request->validate([
            'decision' => ['required', 'in:VERIFIER,CORRIGER'],
            'motif' => ['nullable', 'string', 'min:8', 'max:1000'],
        ]));
        $teacherId = $this->teacherId($request);
        $row = DB::table('gnu.transmission_note')->where('id', $transmission)->where('enseignant_id', $teacherId)->first();
        abort_unless($row !== null, 404, 'Transmission introuvable.');
        abort_unless($row->statut === 'A_VERIFIER', 409, 'La cellule doit d’abord retourner la transmission pour vérification.');

        DB::transaction(function () use ($request, $data, $row): void {
            DB::table('gnu.affectation')->where('id', $row->affectation_id)->lockForUpdate()->first();
            $locked = DB::table('gnu.transmission_note')->where('id', $row->id)->lockForUpdate()->first();
            abort_unless($locked?->statut === 'A_VERIFIER', 409, 'La transmission a déjà été traitée. Rechargez le carnet.');
            $this->setAuditContext($request, $data['motif']);
            if ($data['decision'] === 'CORRIGER') {
                DB::table('gnu.transmission_note')->where('id', $row->id)->update([
                    'statut' => 'A_CORRIGER', 'motif' => trim($data['motif']), 'verifie_par' => null,
                    'verifie_le' => null, 'updated_at' => now(),
                ]);

                return;
            }
            $digitized = DB::table('gnu.note_numerisee')->where('transmission_id', $row->id)->lockForUpdate()->get();
            $gradeCount = DB::table('gnu.note')->where('evaluation_id', $row->evaluation_id)->count();
            abort_unless($gradeCount > 0 && $digitized->count() === $gradeCount, 409, 'La grille n’a pas été entièrement numérisée par la cellule.');
            foreach ($digitized as $digitizedGrade) {
                $note = DB::table('gnu.note')->where('evaluation_id', $row->evaluation_id)
                    ->where('inscription_ue_id', $digitizedGrade->inscription_ue_id)->lockForUpdate()->first();
                abort_unless($note !== null && (int) $note->version_note === (int) $digitizedGrade->version_note_source, 409, 'Une note a changé depuis sa numérisation. Demandez à la cellule de recharger la grille.');
                DB::select("SELECT set_config('gnu.origine', ?, true), set_config('gnu.decision_id', '', true)", ['CORRECTION']);
                DB::table('gnu.note')->where('id', $note->id)->update([
                    'valeur_note' => $digitizedGrade->situation === 'NUMERIQUE' ? $digitizedGrade->valeur_note : null,
                    'situation' => $digitizedGrade->situation,
                    'statut_note' => 'BROUILLON',
                    'validateur_id' => null,
                    'date_validation' => null,
                    'version_note' => $note->version_note,
                    'updated_at' => now(),
                ]);
            }
            DB::select("SELECT set_config('gnu.origine', ?, true), set_config('gnu.decision_id', '', true)", ['VALIDATION_ENSEIGNANT']);
            DB::table('gnu.note')->where('evaluation_id', $row->evaluation_id)->where('statut_note', 'BROUILLON')
                ->whereIn('situation', ['NUMERIQUE', 'ABSENTE'])->update([
                    'statut_note' => 'VALIDEE', 'validateur_id' => $request->user()->id, 'date_validation' => now(), 'updated_at' => now(),
                ]);
            DB::table('gnu.transmission_note')->where('id', $row->id)->update([
                'statut' => 'VERIFIEE', 'motif' => trim($data['motif']), 'verifie_par' => $request->user()->id,
                'verifie_le' => now(), 'updated_at' => now(),
            ]);
            $resolvedRequests = DB::table('gnu.requete as r')
                ->join('gnu.decision_requete as d', function ($join): void {
                    $join->on('d.requete_id', '=', 'r.id')->where('d.courante', true);
                })
                ->join('gnu.note as n', function ($join): void {
                    $join->on('n.evaluation_id', '=', 'r.evaluation_id')
                        ->on('n.inscription_ue_id', '=', 'r.inscription_ue_id');
                })
                ->join('gnu.inscription_ue as iu', 'iu.id', '=', 'r.inscription_ue_id')
                ->join('gnu.inscription_classe as ic', 'ic.id', '=', 'iu.inscription_classe_id')
                ->join('gnu.etudiant as e', 'e.id', '=', 'ic.etudiant_id')
                ->where('r.evaluation_id', $row->evaluation_id)
                ->where('r.type_requete', 'NOTE_MANQUANTE')
                ->where('r.statut_requete', 'EN_TRAITEMENT')
                ->where('d.action_decision', 'AUTORISER_EVALUATION')
                ->where('n.statut_note', 'VALIDEE')
                ->whereIn('n.situation', ['NUMERIQUE', 'ABSENTE'])
                ->get(['r.id', 'e.utilisateur_id as destinataire_id']);
            foreach ($resolvedRequests as $resolvedRequest) {
                DB::table('gnu.requete')->where('id', $resolvedRequest->id)->update([
                    'statut_requete' => 'DECIDEE',
                    'updated_at' => now(),
                ]);
                DB::table('gnu.agent_requete_transmission')->where('requete_id', $resolvedRequest->id)->where('courante', true)
                    ->update(['courante' => false]);
                DB::table('gnu.notification')->insertOrIgnore([
                    'destinataire_id' => $resolvedRequest->destinataire_id,
                    'requete_id' => $resolvedRequest->id,
                    'type_notification' => 'REQUETE_DECIDEE',
                    'cle_evenement' => 'REQUETE|'.$resolvedRequest->id.'|NOTE_VERIFIEE|T'.$row->id,
                    'contenu' => json_encode([
                        'titre' => 'Note manquante corrigée',
                        'message' => 'La note a été corrigée, vérifiée par l’enseignant et intégrée aux résultats provisoires.',
                        'decision' => 'NOTE_CORRIGEE',
                    ], JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE),
                    'date_envoi' => now(),
                    'statut_envoi' => 'ENVOYEE',
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);
            }
        });

        return response()->json(['message' => $data['decision'] === 'VERIFIER' ? 'Notes vérifiées et intégrées aux résultats provisoires.' : 'La transmission a été retournée pour correction.']);
    }

    private function assertGradesEditable(int $evaluation, ?int $inscriptionUE = null): void
    {
        $current = DB::table('gnu.transmission_note')->where('evaluation_id', $evaluation)->orderByDesc('version')->first();
        $authorizedCorrection = $inscriptionUE !== null
            && $current?->statut === 'VERIFIEE'
            && $this->hasAuthorizedMissingNoteCorrection($evaluation, $inscriptionUE);
        abort_if(
            $current !== null
                && in_array($current->statut, ['TRANSMISE', 'A_VERIFIER', 'VERIFIEE'], true)
                && ! $authorizedCorrection,
            409,
            'Les notes sont verrouillées pendant le circuit de validation. Une correction doit être autorisée par une requête de note manquante.',
        );
    }

    private function hasAuthorizedMissingNoteCorrection(int $evaluation, int $inscriptionUE): bool
    {
        return $this->authorizedMissingNoteCorrectionDecisionId($evaluation, $inscriptionUE) !== null;
    }

    private function authorizedMissingNoteCorrectionDecisionId(int $evaluation, int $inscriptionUE): ?int
    {
        $decisionId = DB::table('gnu.requete as r')
            ->join('gnu.decision_requete as d', function ($join): void {
                $join->on('d.requete_id', '=', 'r.id')->where('d.courante', true);
            })
            ->where('r.evaluation_id', $evaluation)
            ->where('r.inscription_ue_id', $inscriptionUE)
            ->where('r.type_requete', 'NOTE_MANQUANTE')
            ->where('r.statut_requete', 'EN_TRAITEMENT')
            ->where('d.action_decision', 'AUTORISER_EVALUATION')
            ->value('d.id');

        return $decisionId === null ? null : (int) $decisionId;
    }

    private function hasPreparedMissingNoteCorrection(int $evaluation): bool
    {
        return DB::table('gnu.requete as r')
            ->join('gnu.decision_requete as d', function ($join): void {
                $join->on('d.requete_id', '=', 'r.id')->where('d.courante', true);
            })
            ->join('gnu.note as n', function ($join): void {
                $join->on('n.evaluation_id', '=', 'r.evaluation_id')
                    ->on('n.inscription_ue_id', '=', 'r.inscription_ue_id');
            })
            ->where('r.evaluation_id', $evaluation)
            ->where('r.type_requete', 'NOTE_MANQUANTE')
            ->where('r.statut_requete', 'EN_TRAITEMENT')
            ->where('d.action_decision', 'AUTORISER_EVALUATION')
            ->where('n.statut_note', 'BROUILLON')
            ->whereIn('n.situation', ['NUMERIQUE', 'ABSENTE'])
            ->exists();
    }

    private function planData(int $affectation, int $teacherId): array
    {
        $assignment = $this->ownedAssignment($affectation, $teacherId);
        $latestVersion = DB::table('gnu.plan_evaluation')->where('affectation_id', $affectation)->where('portee', 'CLASSE')->max('version_plan');
        $components = $latestVersion === null ? collect() : DB::table('gnu.plan_evaluation as pe')
            ->join('gnu.ligne_plan as lp', 'lp.plan_id', '=', 'pe.id')
            ->join('gnu.evaluation as ev', 'ev.id', '=', 'lp.evaluation_id')
            ->where('pe.affectation_id', $affectation)->where('pe.portee', 'CLASSE')->where('pe.version_plan', $latestVersion)
            ->orderBy('ev.date_evaluation')->orderBy('ev.id')
            ->get(['ev.id as evaluation_id', 'ev.type_eval', 'ev.date_evaluation', 'ev.statut_evaluation', 'lp.poids_evaluation']);
        $weights = $components->mapWithKeys(fn (object $component): array => [(string) $component->evaluation_id => (float) $component->poids_evaluation])->all();
        $planIsValid = true;
        $validationMessage = null;
        try {
            $rules = app(AcademicRules::class);
            $rules->validateEvaluationWeights($weights);
            $rules->validateOfficialEvaluationWeights($components->map(fn (object $component): array => [
                'type_eval' => $component->type_eval,
                'poids' => $component->poids_evaluation,
            ])->all());
        } catch (DomainException $exception) {
            $planIsValid = false;
            $validationMessage = $exception->getMessage();
        }

        return [
            'affectation_id' => $affectation,
            'classe_id' => (int) $assignment->classe_id,
            'code_classe' => $assignment->code_classe,
            'code_ue' => $assignment->code_ue,
            'code_matiere' => $assignment->code_m,
            'version' => $latestVersion === null ? null : (int) $latestVersion,
            'plan_valide' => $planIsValid,
            'message_validation' => $validationMessage,
            'composantes' => $components->map(function (object $component): array {
                $transmission = DB::table('gnu.transmission_note')->where('evaluation_id', $component->evaluation_id)->orderByDesc('version')->first();
                $authorizedCorrection = DB::table('gnu.requete as r')
                    ->join('gnu.decision_requete as d', function ($join): void {
                        $join->on('d.requete_id', '=', 'r.id')->where('d.courante', true);
                    })
                    ->where('r.evaluation_id', $component->evaluation_id)
                    ->where('r.type_requete', 'NOTE_MANQUANTE')
                    ->where('r.statut_requete', 'EN_TRAITEMENT')
                    ->where('d.action_decision', 'AUTORISER_EVALUATION')
                    ->exists();
                $correctionReady = $authorizedCorrection && DB::table('gnu.requete as r')
                    ->join('gnu.decision_requete as d', function ($join): void {
                        $join->on('d.requete_id', '=', 'r.id')->where('d.courante', true);
                    })
                    ->join('gnu.note as n', function ($join): void {
                        $join->on('n.evaluation_id', '=', 'r.evaluation_id')
                            ->on('n.inscription_ue_id', '=', 'r.inscription_ue_id');
                    })
                    ->where('r.evaluation_id', $component->evaluation_id)
                    ->where('r.type_requete', 'NOTE_MANQUANTE')
                    ->where('r.statut_requete', 'EN_TRAITEMENT')
                    ->where('d.action_decision', 'AUTORISER_EVALUATION')
                    ->where('n.statut_note', 'BROUILLON')
                    ->whereIn('n.situation', ['NUMERIQUE', 'ABSENTE'])
                    ->exists();

                return [
                    'evaluation_id' => (int) $component->evaluation_id,
                    'type_eval' => $component->type_eval,
                    'date_evaluation' => $component->date_evaluation,
                    'statut_evaluation' => $component->statut_evaluation,
                    'poids_evaluation' => (float) $component->poids_evaluation,
                    'correction_autorisee' => $authorizedCorrection,
                    'correction_prete' => $correctionReady,
                    'transmission' => $transmission === null ? null : [
                        'id' => (int) $transmission->id,
                        'version' => (int) $transmission->version,
                        'statut' => $transmission->statut,
                        'motif' => $transmission->motif,
                    ],
                ];
            })->values()->all(),
        ];
    }

    /** @param array<string, mixed> $data
     * @return array<string, mixed>
     */
    private function normalizeOptionalMotif(array $data): array
    {
        $motif = trim((string) ($data['motif'] ?? ''));
        $data['motif'] = $motif !== '' ? $motif : 'Action effectuée sans motif précisé.';

        return $data;
    }

    private function setAuditContext(Request $request, string $reason): void
    {
        DB::select("SELECT set_config('gnu.acteur_id', ?, true), set_config('gnu.motif', ?, true)", [(string) $request->user()->id, $reason]);
    }
}
