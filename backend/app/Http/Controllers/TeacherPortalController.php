<?php

namespace App\Http\Controllers;

use App\Services\AcademicRules;
use App\Services\GradeSpreadsheetReader;
use App\Services\GradeWorkbookWriter;
use DomainException;
use Illuminate\Database\QueryException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpFoundation\File\UploadedFile;

class TeacherPortalController extends Controller
{
    public function rooms(Request $request): JsonResponse
    {
        $teacherId = $this->teacherId($request);
        $years = DB::table('gnu.annee_academique')->orderByDesc('date_debut')
            ->get(['id', 'libelle', 'date_debut', 'date_fin']);
        abort_if($years->isEmpty(), 404, 'Aucune année académique n’est configurée.');
        $currentYearId = (int) $years->first()->id;
        $yearId = $request->filled('annee_id') ? $request->integer('annee_id') : $currentYearId;
        abort_unless($years->contains(fn (object $year): bool => (int) $year->id === $yearId), 404, 'Année académique introuvable.');

        $rooms = DB::table('gnu.classe as c')
            ->join('gnu.annee_academique as an', 'an.id', '=', 'c.annee_id')
            ->join('gnu.niveau as n', 'n.id', '=', 'c.niveau_id')
            ->join('gnu.filiere as f', 'f.id', '=', 'n.filiere_id')
            ->join('gnu.departement as d', 'd.id', '=', 'f.departement_id')
            ->leftJoin('gnu.specialite as s', 's.id', '=', 'n.specialite_id')
            ->leftJoin('gnu.adhesion_salle_enseignant as adh', function ($join) use ($teacherId): void {
                $join->on('adh.classe_id', '=', 'c.id')->where('adh.enseignant_id', '=', $teacherId);
            })
            ->leftJoin('gnu.inscription_classe as ic', function ($join): void {
                $join->on('ic.classe_id', '=', 'c.id')->where('ic.statut_inscription', '=', 'VALIDEE');
            })
            ->where('c.annee_id', $yearId)
            ->groupBy('c.id', 'c.code_classe', 'an.id', 'an.libelle', 'an.date_debut', 'n.code_niv', 'n.libelle_niv', 'f.code_f', 'f.nom_f', 'd.nom_depart', 's.libelle_specialite', 'adh.id')
            ->orderBy('c.code_classe')
            ->get([
                'c.id as classe_id', 'c.code_classe', 'an.id as annee_id', 'an.libelle as annee_academique',
                'n.code_niv', 'n.libelle_niv', 'f.code_f', 'f.nom_f', 'd.nom_depart',
                's.libelle_specialite', 'adh.id as adhesion_id',
                DB::raw('count(DISTINCT ic.id)::int as effectif'),
            ])->map(function (object $room) use ($yearId, $currentYearId): array {
                $room->effectif = (int) $room->effectif;
                $room->choisie = $room->adhesion_id !== null;
                $room->annee_courante = $yearId === $currentYearId;
                $room->effectif_selectionnee = $room->choisie ? $room->effectif : 0;

                return (array) $room;
            });

        return response()->json(['annee_id' => $yearId, 'annee_courante_id' => $currentYearId, 'annees' => $years, 'data' => $rooms]);
    }

    public function joinRoom(Request $request, int $classe): JsonResponse
    {
        $teacherId = $this->teacherId($request);
        $currentYearId = DB::table('gnu.annee_academique')->orderByDesc('date_debut')->value('id');
        abort_unless($currentYearId !== null, 404, 'Aucune année académique n’est configurée.');
        abort_unless(DB::table('gnu.classe')->where('id', $classe)->where('annee_id', $currentYearId)->exists(), 404, 'Cette salle n’est pas ouverte pour l’année académique en cours.');
        abort_if(DB::table('gnu.adhesion_salle_enseignant')->where('enseignant_id', $teacherId)->where('classe_id', $classe)->exists(), 409, 'Vous avez déjà rejoint cette salle.');

        $id = DB::transaction(function () use ($request, $teacherId, $classe): int {
            $this->setAuditContext($request, 'Adhésion volontaire d’un enseignant à une salle');

            return (int) DB::table('gnu.adhesion_salle_enseignant')->insertGetId([
                'enseignant_id' => $teacherId,
                'classe_id' => $classe,
                'created_at' => now(),
                'updated_at' => now(),
            ], 'id');
        });

        return response()->json(['id' => $id, 'message' => 'Vous avez rejoint la salle.'], 201);
    }

    public function roomStudents(Request $request, int $classe): JsonResponse
    {
        $teacherId = $this->teacherId($request);
        abort_unless(DB::table('gnu.adhesion_salle_enseignant')->where('enseignant_id', $teacherId)->where('classe_id', $classe)->exists(), 403, 'Rejoignez cette salle pour consulter ses élèves.');
        $room = DB::table('gnu.classe as c')
            ->join('gnu.annee_academique as an', 'an.id', '=', 'c.annee_id')
            ->where('c.id', $classe)->first(['c.id', 'c.code_classe', 'an.libelle as annee_academique']);
        abort_unless($room !== null, 404);
        $students = DB::table('gnu.inscription_classe as ic')
            ->join('gnu.etudiant as e', 'e.id', '=', 'ic.etudiant_id')
            ->join('gnu.utilisateur as u', 'u.id', '=', 'e.utilisateur_id')
            ->where('ic.classe_id', $classe)->where('ic.statut_inscription', 'VALIDEE')
            ->orderBy('u.nom')->orderBy('u.prenom')
            ->get(['ic.id as inscription_classe_id', 'e.id as etudiant_id', 'e.matricule', 'u.nom', 'u.prenom', 'ic.statut_redoublant']);

        return response()->json(['salle' => $room, 'data' => $students]);
    }

    public function exportRoomRoster(Request $request, int $classe, GradeWorkbookWriter $writer)
    {
        $teacherId = $this->teacherId($request);
        abort_unless(DB::table('gnu.adhesion_salle_enseignant')
            ->where('enseignant_id', $teacherId)->where('classe_id', $classe)->exists(), 403, 'Rejoignez cette salle pour télécharger son effectif.');

        $room = DB::table('gnu.classe as c')
            ->join('gnu.niveau as n', 'n.id', '=', 'c.niveau_id')
            ->join('gnu.annee_academique as an', 'an.id', '=', 'c.annee_id')
            ->where('c.id', $classe)
            ->first(['c.code_classe', 'n.code_niv', 'n.libelle_niv', 'an.libelle as annee_academique']);
        abort_if($room === null, 404, 'Salle introuvable.');

        $students = DB::table('gnu.inscription_classe as ic')
            ->join('gnu.etudiant as e', 'e.id', '=', 'ic.etudiant_id')
            ->join('gnu.utilisateur as u', 'u.id', '=', 'e.utilisateur_id')
            ->where('ic.classe_id', $classe)->where('ic.statut_inscription', 'VALIDEE')
            ->orderBy('u.nom')->orderBy('u.prenom')->orderBy('e.matricule')
            ->get(['e.matricule', 'u.nom', 'u.prenom'])
            ->map(fn (object $student): array => [
                $student->matricule,
                $student->nom,
                $student->prenom,
                $room->code_niv.' · '.$room->libelle_niv,
                $room->code_classe,
            ])->all();

        $rows = [[
            'Matricule', 'Nom', 'Prénom', 'Niveau', 'Classe',
        ], ...$students];
        $filename = $this->safeFilename('effectif-'.$room->code_classe.'-'.$room->annee_academique).'.xlsx';

        return response()->streamDownload(
            static function () use ($writer, $rows): void {
                echo $writer->write([['name' => 'Effectif', 'rows' => $rows]]);
            },
            $filename,
            ['Content-Type' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'],
        );
    }

    public function courseOptions(Request $request, int $classe): JsonResponse
    {
        $teacherId = $this->teacherId($request);
        abort_unless(DB::table('gnu.adhesion_salle_enseignant')
            ->where('enseignant_id', $teacherId)->where('classe_id', $classe)->exists(), 403, 'Rejoignez cette salle pour consulter son programme.');
        $class = DB::table('gnu.classe')->where('id', $classe)->first(['id', 'niveau_id']);
        abort_unless($class !== null, 404, 'Classe introuvable.');
        $semester = $request->integer('semestre');
        abort_if($request->filled('semestre') && ! in_array($semester, [1, 2], true), 422, 'Semestre invalide.');

        $units = DB::table('gnu.ue as u')
            ->where('u.niveau_id', $class->niveau_id)
            ->where('u.statut_catalogue', 'ACTIF')
            ->when($request->filled('semestre'), fn ($query) => $query->where('u.numero_semestre', $semester))
            ->orderBy('u.numero_semestre')->orderBy('u.code_ue')
            ->get(['u.id', 'u.code_ue', 'u.intitule_ue', 'u.numero_semestre']);
        $unitIds = $units->pluck('id')->all();
        $elements = $unitIds === [] ? collect() : DB::table('gnu.matiere as m')
            ->whereIn('m.ue_id', $unitIds)->orderBy('m.ue_id')->orderBy('m.rang_ec')
            ->get(['m.id', 'm.ue_id', 'm.code_m', 'm.intitule_matiere', 'm.rang_ec']);
        $assignments = DB::table('gnu.affectation as a')
            ->where('a.classe_id', $classe)->where('a.enseignant_id', $teacherId)
            ->get(['a.id', 'a.matiere_id', 'a.actif'])->keyBy('matiere_id');
        $pending = [];
        $latestProposals = collect();
        $pendingByOther = [];
        $proposalsAvailable = true;
        try {
            $pending = DB::table('gnu.proposition_affectation_enseignant as p')
                ->join('gnu.affectation as a', 'a.id', '=', 'p.affectation_id')
                ->where('a.classe_id', $classe)->where('a.enseignant_id', $teacherId)->where('p.statut', 'EN_ATTENTE')
                ->pluck('a.matiere_id')->map(static fn (mixed $id): int => (int) $id)->all();
            $latestProposals = DB::table('gnu.proposition_affectation_enseignant as p')
                ->join('gnu.affectation as a', 'a.id', '=', 'p.affectation_id')
                ->where('a.classe_id', $classe)->where('a.enseignant_id', $teacherId)
                ->orderByDesc('p.id')->get(['a.matiere_id', 'p.statut', 'p.motif_decision'])
                ->unique('matiere_id')->keyBy('matiere_id');
            $pendingByOther = DB::table('gnu.proposition_affectation_enseignant as p')
                ->join('gnu.affectation as a', 'a.id', '=', 'p.affectation_id')
                ->where('a.classe_id', $classe)->where('a.enseignant_id', '<>', $teacherId)->where('p.statut', 'EN_ATTENTE')
                ->pluck('a.matiere_id')->map(static fn (mixed $id): int => (int) $id)->all();
        } catch (QueryException $exception) {
            if ((string) $exception->getCode() !== '42P01') {
                throw $exception;
            }
            $proposalsAvailable = false;
        }
        $occupied = DB::table('gnu.affectation')->where('classe_id', $classe)->where('actif', true)
            ->pluck('matiere_id')->map(static fn (mixed $id): int => (int) $id)->all();

        return response()->json(['data' => $units->map(fn (object $unit): array => [
            'id' => (int) $unit->id,
            'code_ue' => $unit->code_ue,
            'intitule_ue' => $unit->intitule_ue,
            'numero_semestre' => (int) $unit->numero_semestre,
            'propositions_disponibles' => $proposalsAvailable,
            'elements' => $elements->where('ue_id', $unit->id)->map(fn (object $element): array => [
                'id' => (int) $element->id,
                'code_m' => $element->code_m,
                'intitule_matiere' => $element->intitule_matiere,
                'rang_ec' => (int) $element->rang_ec,
                'affectation_id' => isset($assignments[$element->id]) ? (int) $assignments[$element->id]->id : null,
                'motif_decision' => $latestProposals[$element->id]->motif_decision ?? null,
                'statut_affectation' => ! empty($assignments[$element->id]->actif) ? 'APPROUVEE'
                    : (in_array((int) $element->id, $pending, true) ? 'EN_ATTENTE'
                        : (($latestProposals[$element->id]->statut ?? null) === 'REJETEE' ? 'REJETEE'
                            : (in_array((int) $element->id, $occupied, true) || in_array((int) $element->id, $pendingByOther, true) ? 'INDISPONIBLE' : null))),
                'peut_demander_separement' => $proposalsAvailable,
            ])->values(),
        ])]);
    }

    public function assignmentProposals(Request $request): JsonResponse
    {
        $teacherId = $this->teacherId($request);
        $rows = DB::table('gnu.proposition_affectation_enseignant as p')
            ->join('gnu.affectation as a', 'a.id', '=', 'p.affectation_id')
            ->join('gnu.classe as c', 'c.id', '=', 'a.classe_id')
            ->join('gnu.annee_academique as an', 'an.id', '=', 'c.annee_id')
            ->join('gnu.matiere as m', 'm.id', '=', 'a.matiere_id')
            ->join('gnu.ue as u', 'u.id', '=', 'm.ue_id')
            ->leftJoin('gnu.utilisateur as decisionnaire', 'decisionnaire.id', '=', 'p.decidee_par')
            ->where('a.enseignant_id', $teacherId)
            ->orderByDesc('p.soumise_le')
            ->get([
                'p.id', 'p.affectation_id', 'p.statut', 'p.motif_enseignant', 'p.motif_decision',
                'p.soumise_le', 'p.decidee_le', 'decisionnaire.nom as nom_decideur', 'decisionnaire.prenom as prenom_decideur',
                'c.id as classe_id', 'c.code_classe', 'an.libelle as annee_academique',
                'u.code_ue', 'u.intitule_ue', 'u.numero_semestre', 'm.id as matiere_id', 'm.code_m', 'm.intitule_matiere',
            ]);

        return response()->json(['data' => $rows]);
    }

    public function proposeAssignment(Request $request, int $classe): JsonResponse
    {
        $data = $request->validate([
            'matiere_id' => ['required_without:ue_id', 'nullable', 'integer', 'min:1'],
            'ue_id' => ['required_without:matiere_id', 'nullable', 'integer', 'min:1'],
        ]);
        abort_if(isset($data['matiere_id'], $data['ue_id']), 422, 'Choisissez une UE entière ou un seul EC, pas les deux.');
        $teacherId = $this->teacherId($request);
        abort_unless(DB::table('gnu.adhesion_salle_enseignant')
            ->where('enseignant_id', $teacherId)->where('classe_id', $classe)->exists(), 403, 'Rejoignez cette salle avant de proposer une matière.');
        $yearId = DB::table('gnu.annee_academique')->orderByDesc('date_debut')->value('id');
        $class = DB::table('gnu.classe')->where('id', $classe)->where('annee_id', $yearId)->first(['id', 'niveau_id']);
        abort_unless($class !== null, 422, 'Les propositions ne sont ouvertes que pour une classe de l’année académique courante.');
        $elements = DB::table('gnu.matiere as m')->join('gnu.ue as u', 'u.id', '=', 'm.ue_id')
            ->where('u.niveau_id', $class->niveau_id)
            ->where('u.statut_catalogue', 'ACTIF')
            ->when(isset($data['ue_id']), fn ($query) => $query->where('u.id', $data['ue_id']))
            ->when(isset($data['matiere_id']), fn ($query) => $query->where('m.id', $data['matiere_id']))
            ->orderBy('m.rang_ec')->get(['m.id']);
        abort_unless($elements->isNotEmpty(), 422, 'Cette UE ou cet EC ne correspond pas au niveau et au programme de la classe.');

        $result = DB::transaction(function () use ($request, $teacherId, $classe, $elements): array {
            DB::table('gnu.classe')->where('id', $classe)->lockForUpdate()->first();
            $this->setAuditContext($request, 'Confirmation de choix d’enseignement pour validation par la cellule');
            $proposalIds = [];
            $skipped = 0;
            foreach ($elements as $element) {
                $active = DB::table('gnu.affectation')->where('classe_id', $classe)
                    ->where('matiere_id', $element->id)->where('actif', true)->exists();
                $pending = DB::table('gnu.proposition_affectation_enseignant as p')
                    ->join('gnu.affectation as a', 'a.id', '=', 'p.affectation_id')
                    ->where('a.classe_id', $classe)->where('a.matiere_id', $element->id)
                    ->where('p.statut', 'EN_ATTENTE')->exists();
                if ($active || $pending) {
                    $skipped++;

                    continue;
                }

                $assignmentId = DB::table('gnu.affectation')->where('enseignant_id', $teacherId)
                    ->where('classe_id', $classe)->where('matiere_id', $element->id)->where('actif', false)
                    ->orderByDesc('id')->value('id');
                if ($assignmentId === null) {
                    $assignmentId = DB::table('gnu.affectation')->insertGetId([
                        'enseignant_id' => $teacherId,
                        'matiere_id' => $element->id,
                        'classe_id' => $classe,
                        'actif' => false,
                        'created_at' => now(),
                        'updated_at' => now(),
                    ], 'id');
                }

                $proposalIds[] = (int) DB::table('gnu.proposition_affectation_enseignant')->insertGetId([
                    'affectation_id' => $assignmentId,
                    'statut' => 'EN_ATTENTE',
                    'soumise_par' => $request->user()->id,
                    'motif_enseignant' => '',
                    'created_at' => now(),
                    'updated_at' => now(),
                ], 'id');
            }
            abort_if($proposalIds === [], 409, 'Aucun EC disponible : ils sont déjà attribués ou font déjà l’objet d’une demande.');

            return ['ids' => $proposalIds, 'skipped' => $skipped];
        });

        $count = count($result['ids']);

        return response()->json([
            'ids' => $result['ids'],
            'nombre_ec' => $count,
            'ec_ignores' => $result['skipped'],
            'statut' => 'EN_ATTENTE',
            'message' => $count === 1
                ? 'Le choix d’enseignement pour cet EC a été transmis à la cellule.'
                : "{$count} choix d’enseignement ont été transmis à la cellule.",
        ], 201);
    }

    public function assignments(Request $request): JsonResponse
    {
        $teacherId = DB::table('gnu.enseignant')
            ->where('utilisateur_id', $request->user()->id)
            ->value('id');
        abort_unless($teacherId !== null, 404, 'Profil enseignant introuvable.');

        $assignments = DB::table('gnu.affectation as a')
            ->join('gnu.classe as c', 'c.id', '=', 'a.classe_id')
            ->join('gnu.niveau as n', 'n.id', '=', 'c.niveau_id')
            ->join('gnu.matiere as m', 'm.id', '=', 'a.matiere_id')
            ->join('gnu.ue as u', 'u.id', '=', 'm.ue_id')
            ->join('gnu.annee_academique as an', 'an.id', '=', 'c.annee_id')
            ->leftJoin('gnu.responsable_note_ue as rnu', function ($join): void {
                $join->on('rnu.classe_id', '=', 'a.classe_id')->on('rnu.ue_id', '=', 'u.id');
            })
            ->leftJoin('gnu.enseignant as rnue', 'rnue.id', '=', 'rnu.enseignant_id')
            ->leftJoin('gnu.utilisateur as rnuu', 'rnuu.id', '=', 'rnue.utilisateur_id')
            ->where(function ($query) use ($teacherId): void {
                $query->where('a.enseignant_id', $teacherId)->orWhere('rnu.enseignant_id', $teacherId);
            })
            ->where('a.actif', true)
            ->when($request->filled('annee_id'), fn ($query) => $query->where('c.annee_id', $request->integer('annee_id')))
            ->orderByDesc('an.date_debut')
            ->orderBy('c.code_classe')
            ->orderBy('u.code_ue')
            ->orderBy('m.rang_ec')
            ->get([
                'a.id as affectation_id', 'c.id as classe_id', 'c.code_classe',
                'an.libelle as annee_academique', 'n.code_niv', 'n.libelle_niv',
                'u.id as ue_id', 'u.code_ue',
                'u.intitule_ue', 'u.numero_semestre', 'm.id as matiere_id', 'm.code_m', 'm.intitule_matiere',
                'rnu.enseignant_id as responsable_notes_enseignant_id',
                'rnuu.nom as responsable_notes_nom', 'rnuu.prenom as responsable_notes_prenom',
                'a.enseignant_id as affectation_enseignant_id',
            ])->map(function (object $assignment) use ($teacherId): array {
                return [
                    ...((array) $assignment),
                    'peut_gerer_notes' => (int) ($assignment->responsable_notes_enseignant_id ?? 0) === (int) $teacherId,
                ];
            });

        return response()->json(['data' => $assignments]);
    }

    public function evaluationPlan(Request $request, int $affectation): JsonResponse
    {
        $teacherId = $this->teacherId($request);
        $this->assertCanonicalGradeAssignment($this->ownedAssignment($affectation, $teacherId));

        return response()->json(['data' => $this->planData($affectation, $teacherId)]);
    }

    public function proposeEvaluationProfile(Request $request, int $affectation): JsonResponse
    {
        $data = $request->validate(['code_profil' => ['required', 'in:CC_SN,CC_TP_SN,CC_TPE_SN']]);
        $teacherId = $this->teacherId($request);
        $assignment = $this->ownedAssignment($affectation, $teacherId);
        $this->assertCanonicalGradeAssignment($assignment);
        DB::table('gnu.affectation')->where('id', $assignment->id)->lockForUpdate()->first();
        DB::transaction(function () use ($request, $data, $assignment, $teacherId): void {
            DB::table('gnu.affectation')->where('id', $assignment->id)->lockForUpdate()->first();
            $this->setAuditContext($request, 'Proposition de profil de notation détecté dans le fichier de notes');
            DB::table('gnu.proposition_profil_evaluation')->updateOrInsert(
                ['ue_id' => $assignment->ue_id, 'enseignant_id' => $teacherId, 'code_profil' => $data['code_profil'], 'statut' => 'EN_ATTENTE'],
                ['affectation_id' => $assignment->id, 'updated_at' => now(), 'created_at' => now()],
            );
        });
        $this->ensureOfficialPlan($request, $assignment);

        return response()->json(['message' => 'Le barème a été proposé à la cellule. Le carnet provisoire est prêt; la transmission officielle reste bloquée jusqu’à validation.'], 202);
    }

    public function saveEvaluationPlan(Request $request, int $affectation): JsonResponse
    {
        $data = $this->normalizeOptionalMotif($request->validate([
            'motif' => ['nullable', 'string', 'min:8', 'max:1000'],
            'evaluations' => ['required', 'array', 'min:2', 'max:3'],
            'evaluations.*.evaluation_id' => ['nullable', 'integer', 'min:1', 'distinct'],
            'evaluations.*.type_eval' => ['required', 'in:CC,TP,TPE,SN'],
            'evaluations.*.date_evaluation' => ['required', 'date'],
            'evaluations.*.poids' => ['required', 'numeric', 'gt:0', 'lte:100'],
        ]));
        $teacherId = $this->teacherId($request);
        $assignment = $this->ownedAssignment($affectation, $teacherId);
        $this->assertCanonicalGradeAssignment($assignment);
        $types = array_column($data['evaluations'], 'type_eval');
        abort_if(count($types) !== count(array_unique($types)), 422, 'Une seule évaluation de chaque type est autorisée par UE.');
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
        $this->assertCanonicalGradeAssignment($this->ownedAssignment($affectation, $teacherId));
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
        $request->merge(['salle' => strtoupper(trim((string) $request->input('salle')))]);
        $data = $request->validate([
            'libelle' => ['required', 'string', 'max:255'],
            'date_session' => ['required', 'date', 'after_or_equal:today'],
            'heure_debut' => ['required', 'date_format:H:i'],
            'heure_fin' => ['required', 'date_format:H:i', 'after:heure_debut'],
            'salle' => ['required', 'string', 'max:32', 'regex:/^[A-Z0-9][A-Z0-9-]{0,31}$/'],
        ]);
        $assignment = $this->ownedAssignment($affectation, $this->teacherId($request));
        $teacherId = $this->teacherId($request);
        $id = DB::transaction(function () use ($request, $data, $assignment, $teacherId): int {
            app(AgentPortalController::class)->lockExamSlots(
                $data['date_session'], $data['salle'], (int) $assignment->classe_id, $teacherId,
            );
            $roomConflict = DB::table('gnu.session_rattrapage')->whereDate('date_session', $data['date_session'])
                ->where('salle', $data['salle'])->whereNotNull('heure_debut')
                ->whereRaw('heure_debut < ? AND heure_fin > ?', [$data['heure_fin'], $data['heure_debut']])->exists()
                || DB::table('gnu.evaluation')->whereDate('date_evaluation', $data['date_session'])
                    ->where('salle', $data['salle'])->whereNotNull('heure_debut')
                    ->whereRaw('heure_debut < ? AND heure_fin > ?', [$data['heure_fin'], $data['heure_debut']])->exists();
            abort_if($roomConflict, 409, 'Cette salle est déjà occupée sur ce créneau.');
            $classConflict = DB::table('gnu.session_rattrapage')->where('classe_id', $assignment->classe_id)
                ->whereDate('date_session', $data['date_session'])->whereNotNull('heure_debut')
                ->whereRaw('heure_debut < ? AND heure_fin > ?', [$data['heure_fin'], $data['heure_debut']])->exists()
                || DB::table('gnu.evaluation as ev')->join('gnu.affectation as a', 'a.id', '=', 'ev.affectation_id')
                    ->where('a.classe_id', $assignment->classe_id)->whereDate('ev.date_evaluation', $data['date_session'])
                    ->whereNotNull('ev.heure_debut')->whereRaw('ev.heure_debut < ? AND ev.heure_fin > ?', [$data['heure_fin'], $data['heure_debut']])->exists();
            abort_if($classConflict, 409, 'Cette classe a déjà une évaluation sur ce créneau.');
            $teacherConflict = DB::table('gnu.evaluation as ev')->join('gnu.affectation as a', 'a.id', '=', 'ev.affectation_id')
                ->where('a.enseignant_id', $teacherId)->whereDate('ev.date_evaluation', $data['date_session'])
                ->whereNotNull('ev.heure_debut')->whereRaw('ev.heure_debut < ? AND ev.heure_fin > ?', [$data['heure_fin'], $data['heure_debut']])->exists()
                || DB::table('gnu.session_rattrapage as sr')
                    ->join('gnu.session_rattrapage_ue as sru', 'sru.session_id', '=', 'sr.id')
                    ->join('gnu.matiere as rm', 'rm.ue_id', '=', 'sru.ue_id')
                    ->join('gnu.affectation as ra', function ($join): void {
                        $join->on('ra.classe_id', '=', 'sr.classe_id')->on('ra.matiere_id', '=', 'rm.id')->where('ra.actif', '=', true);
                    })
                    ->where('ra.enseignant_id', $teacherId)->whereDate('sr.date_session', $data['date_session'])
                    ->whereNotNull('sr.heure_debut')->whereRaw('sr.heure_debut < ? AND sr.heure_fin > ?', [$data['heure_fin'], $data['heure_debut']])->exists();
            abort_if($teacherConflict, 409, 'Vous avez déjà une évaluation programmée sur ce créneau.');

            $this->setAuditContext($request, 'Programmation d’une session de rattrapage par l’enseignant');
            $sessionId = (int) DB::table('gnu.session_rattrapage')->insertGetId([
                'classe_id' => $assignment->classe_id,
                'libelle' => trim($data['libelle']),
                'date_session' => $data['date_session'],
                'heure_debut' => $data['heure_debut'],
                'heure_fin' => $data['heure_fin'],
                'salle' => $data['salle'],
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
            $recipients = DB::table('gnu.inscription_classe as ic')
                ->join('gnu.etudiant as e', 'e.id', '=', 'ic.etudiant_id')
                ->join('gnu.inscription_ue as iu', function ($join) use ($assignment): void {
                    $join->on('iu.inscription_classe_id', '=', 'ic.id')
                        ->where('iu.ue_id', '=', $assignment->ue_id)
                        ->where('iu.statut_inscription', '=', 'VALIDEE');
                })
                ->where('ic.classe_id', $assignment->classe_id)->where('ic.statut_inscription', 'VALIDEE')
                ->pluck('e.utilisateur_id')->push((int) $request->user()->id)->unique();
            $content = json_encode([
                'titre' => 'Rattrapage programmé',
                'message' => "{$assignment->code_m} · {$assignment->code_classe} : le {$data['date_session']} de {$data['heure_debut']} à {$data['heure_fin']}, salle {$data['salle']}.",
                'session_id' => $sessionId,
                'date' => $data['date_session'],
                'heure_debut' => $data['heure_debut'],
                'heure_fin' => $data['heure_fin'],
                'salle' => $data['salle'],
            ], JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE);
            foreach ($recipients as $recipientId) {
                DB::table('gnu.notification')->insertOrIgnore([
                    'destinataire_id' => $recipientId,
                    'type_notification' => 'SESSION_RATTRAPAGE',
                    'cle_evenement' => 'RATTRAPAGE|'.$sessionId,
                    'contenu' => $content,
                    'date_envoi' => now(),
                    'statut_envoi' => 'ENVOYEE',
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);
            }

            return $sessionId;
        });

        return response()->json(['id' => $id, 'message' => 'Session de rattrapage programmée. Les étudiants inscrits ont été notifiés.'], 201);
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
                if ($transmission !== null) {
                    $transmission->publie_le = DB::table('gnu.proces_verbal_note')->where('transmission_id', $transmission->id)->value('publie_le');
                }
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
            'notes.*.matricule' => ['required', 'string', 'max:32'],
            'notes.*.situation' => ['required', 'in:NUMERIQUE,ABSENTE'],
            'notes.*.valeur_note' => ['nullable', 'numeric'],
            'notes.*.version_note' => ['nullable', 'integer', 'min:1'],
        ]));
        $data = $this->clampGradeInputs($data);
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
        $this->assertCanonicalGradeAssignment($assignment);
        $proposedProfile = null;
        if (DB::table('gnu.profil_evaluation_ue')->where('ue_id', $assignment->ue_id)->value('code_profil') === null) {
            $proposedProfile = DB::table('gnu.profil_evaluation_ue')->where('ue_id', $assignment->ue_id)->value('code_profil')
                ?? DB::table('gnu.proposition_profil_evaluation')
                    ->where('ue_id', $assignment->ue_id)
                    ->where('enseignant_id', $assignment->enseignant_id)
                    ->where('affectation_id', $assignment->id)
                    ->whereIn('statut', ['EN_ATTENTE', 'APPROUVEE'])
                    ->orderByDesc('created_at')
                    ->value('code_profil');
        }
        if ($assignment->profil_evaluation !== null) {
            $this->ensureOfficialPlan($request, $assignment);
        }
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
        $externalNotes = $evaluationIds === [] ? collect() : DB::table('gnu.note_hors_compte')
            ->where('classe_id', $assignment->classe_id)->whereIn('evaluation_id', $evaluationIds)
            ->orderBy('matricule')->get()->groupBy('matricule');
        $externalDigitizedNotes = collect();
        if ($evaluationIds !== []) {
            $externalDigitizedNotes = DB::table('gnu.note_numerisee_hors_compte as nh')
                ->join('gnu.transmission_note as tn', 'tn.id', '=', 'nh.transmission_id')
                ->whereIn('tn.evaluation_id', $evaluationIds)->where('tn.statut', 'A_VERIFIER')
                ->get(['tn.evaluation_id', 'nh.note_hors_compte_id', 'nh.valeur_note', 'nh.situation'])
                ->keyBy('note_hors_compte_id');
        }
        $registeredMatricules = $students->map(static fn (object $student): string => mb_strtoupper(trim($student->matricule)))->all();
        $externalStudents = $externalNotes->reject(static fn ($rows, string $matricule): bool => in_array(mb_strtoupper(trim($matricule)), $registeredMatricules, true))
            ->map(function ($studentNotes) use ($evaluations, $externalDigitizedNotes): array {
                $identity = $studentNotes->first();
                $notesByEvaluation = $studentNotes->keyBy('evaluation_id');
                $notesForStudent = $evaluations->map(function (array $evaluation) use ($notesByEvaluation, $externalDigitizedNotes): array {
                    $note = $notesByEvaluation->get($evaluation['evaluation_id']);
                    $digitized = $note === null ? null : $externalDigitizedNotes->get($note->id);

                    return [
                        'evaluation_id' => (int) $evaluation['evaluation_id'],
                        'note_id' => $note?->id === null ? null : (int) $note->id,
                        'version_note' => $note?->version_note === null ? null : (int) $note->version_note,
                        'valeur_note' => $note?->valeur_note,
                        'situation' => $note?->situation ?? 'MANQUANTE',
                        'statut_note' => $note?->statut_note ?? 'ABSENTE',
                        'observation' => $note?->observation ?? 'Étudiant non inscrit dans la classe ou l’UE; à vérifier par l’agent.',
                        'valeur_numerisee' => $digitized?->valeur_note,
                        'situation_numerisee' => $digitized?->situation,
                        'hors_compte' => true,
                    ];
                })->values()->all();

                return [
                    'inscription_ue_id' => null,
                    'matricule' => $identity->matricule,
                    'nom' => $identity->nom,
                    'inscription_classe_id' => null,
                    'hors_compte' => true,
                    'observation' => $identity->observation ?? 'Étudiant non inscrit dans la classe ou l’UE; à vérifier par l’agent.',
                    'fiche_academique_disponible' => false,
                    'notes' => $notesForStudent,
                    'resultat_ec_provisoire' => null,
                    'resultat_ue_provisoire' => null,
                ];
            })->values();
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
        $logo = DB::table('gnu.logo_structure')->where('departement_id', $assignment->departement_id)
            ->first(['chemin_fichier', 'type_mime']);
        $logoStructure = $logo !== null && Storage::disk('local')->exists($logo->chemin_fichier)
            ? ['mime' => $logo->type_mime, 'base64' => base64_encode(Storage::disk('local')->get($logo->chemin_fichier))]
            : null;

        return response()->json(['data' => [
            'affectation_id' => $affectation,
            'affectation_active' => (bool) $assignment->actif,
            'affectation_statut' => $assignment->actif ? 'APPROUVEE' : 'EN_ATTENTE',
            'profil_evaluation' => $assignment->profil_evaluation,
            'profil_propose' => $proposedProfile,
            'classe' => $assignment->code_classe,
            'code_classe' => $assignment->code_classe,
            'annee_academique' => $assignment->annee_academique,
            'niveau' => $assignment->libelle_niv,
            'numero_semestre' => (int) $assignment->numero_semestre,
            'code_ue' => $assignment->code_ue,
            'intitule_ue' => $assignment->intitule_ue,
            'code_matiere' => $assignment->code_m,
            'intitule_matiere' => $assignment->intitule_matiere,
            'faculte' => $assignment->nom_fac,
            'departement' => $assignment->nom_depart,
            'universite' => $assignment->nom_univ,
            'logo_structure' => $logoStructure,
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
                $provisionalUe = null;
                try {
                    $result = DB::selectOne('SELECT gnu.calculer_ec(?, ?) AS contenu', [$student->inscription_ue_id, $assignment->matiere_id]);
                    $provisionalEc = is_string($result->contenu) ? json_decode($result->contenu, true, flags: JSON_THROW_ON_ERROR) : (array) $result->contenu;
                } catch (\Throwable) {
                    $provisionalEc = null;
                }
                try {
                    $result = DB::selectOne('SELECT gnu.calculer_ue_provisoire(?) AS contenu', [$student->inscription_ue_id]);
                    $provisionalUe = is_string($result->contenu) ? json_decode($result->contenu, true, flags: JSON_THROW_ON_ERROR) : (array) $result->contenu;
                } catch (\Throwable) {
                    $provisionalUe = null;
                }

                return [
                    'inscription_ue_id' => (int) $student->inscription_ue_id,
                    'matricule' => $student->matricule,
                    'nom' => trim($student->prenom.' '.$student->nom),
                    'inscription_classe_id' => (int) $student->inscription_classe_id,
                    'fiche_academique_disponible' => $sheetPaths[(int) $student->inscription_classe_id] ?? false,
                    'notes' => $studentNotes,
                    'resultat_ec_provisoire' => $provisionalEc,
                    'resultat_ue_provisoire' => $provisionalUe,
                ];
            })->concat($externalStudents)->sortBy('matricule')->values(),
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
            'notes.*.matricule' => ['required', 'string', 'max:32'],
            'notes.*.nom' => ['nullable', 'string', 'max:180'],
            'notes.*.situation' => ['required', 'in:NUMERIQUE,ABSENTE,MANQUANTE'],
            'notes.*.valeur_note' => ['nullable', 'numeric'],
            'notes.*.version_note' => ['nullable', 'integer', 'min:1'],
        ]));
        $data = $this->clampGradeInputs($data);
        $teacherId = $this->teacherId($request);
        $assignment = $this->ownedAssignment($affectation, $teacherId);
        $this->assertCanonicalGradeAssignment($assignment);
        $assignmentProfile = DB::table('gnu.profil_evaluation_ue')->where('ue_id', $assignment->ue_id)->value('code_profil');
        $event = $assignmentProfile !== null
            ? $this->activeEvaluation($affectation, $evaluation)
            : DB::table('gnu.evaluation')->where('id', $evaluation)
                ->where('affectation_id', $affectation)->first();
        abort_unless($event !== null, 404, 'Évaluation introuvable.');
        abort_unless($event->mode_evaluation === 'NORMALE', 404, 'Évaluation introuvable.');

        $studentIds = DB::table('gnu.inscription_classe as ic')
            ->join('gnu.etudiant as e', 'e.id', '=', 'ic.etudiant_id')
            ->join('gnu.inscription_ue as iu', function ($join) use ($assignment): void {
                $join->on('iu.inscription_classe_id', '=', 'ic.id')->where('iu.ue_id', '=', $assignment->ue_id);
            })
            ->where('ic.classe_id', $assignment->classe_id)->where('ic.statut_inscription', 'VALIDEE')
            ->where('iu.statut_inscription', 'VALIDEE')->get(['e.matricule', 'iu.id as inscription_ue_id'])
            ->keyBy(fn (object $student): string => mb_strtoupper(trim($student->matricule)));
        $classStudents = DB::table('gnu.inscription_classe as ic')
            ->join('gnu.etudiant as e', 'e.id', '=', 'ic.etudiant_id')
            ->leftJoin('gnu.utilisateur as u', 'u.id', '=', 'e.utilisateur_id')
            ->where('ic.classe_id', $assignment->classe_id)->where('ic.statut_inscription', 'VALIDEE')
            ->get(['e.matricule', 'u.nom', 'u.prenom'])
            ->keyBy(fn (object $student): string => mb_strtoupper(trim($student->matricule)));
        $seenMatricules = [];
        foreach ($data['notes'] as $index => $row) {
            $data['notes'][$index]['matricule'] = mb_strtoupper(trim($row['matricule']));
            $row = $data['notes'][$index];
            abort_if(isset($seenMatricules[$row['matricule']]), 422, 'Un matricule ne peut apparaître qu’une seule fois dans la grille.');
            $seenMatricules[$row['matricule']] = true;
            if ($row['situation'] === 'NUMERIQUE' && (! isset($row['valeur_note']) || ! is_numeric($row['valeur_note']))) {
                throw ValidationException::withMessages(["notes.$index.valeur_note" => ['Une note numérique est obligatoire pour cette situation.']]);
            }
            if ($row['situation'] !== 'NUMERIQUE' && $row['valeur_note'] !== null) {
                throw ValidationException::withMessages(["notes.$index.valeur_note" => ['Une valeur numérique n’est pas permise pour une absence ou une note manquante.']]);
            }
            if (! $studentIds->has($row['matricule'])) {
                abort_if(trim((string) ($row['nom'] ?? '')) === '', 422, 'Indiquez le nom de chaque étudiant ajouté hors de la liste de l’UE.');
            } elseif ($assignment->actif) {
                $this->assertGradesEditable($evaluation, (int) $studentIds[$row['matricule']]->inscription_ue_id);
            }
        }

        $saved = DB::transaction(function () use ($request, $data, $evaluation, $studentIds, $classStudents, $affectation, $assignment): int {
            DB::table('gnu.affectation')->where('id', $affectation)->lockForUpdate()->first();
            $this->setAuditContext($request, $data['motif']);
            $this->markEvaluationRealized($evaluation);
            $count = 0;
            foreach ($data['notes'] as $row) {
                if ($studentIds->has($row['matricule'])) {
                    $registrationId = (int) $studentIds[$row['matricule']]->inscription_ue_id;
                    if ($assignment->actif) {
                        $this->assertGradesEditable($evaluation, $registrationId);
                    }
                    $existing = DB::table('gnu.note')->where('evaluation_id', $evaluation)->where('inscription_ue_id', $registrationId)->lockForUpdate()->first();
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
                } else {
                    $matricule = mb_strtoupper(trim($row['matricule']));
                    if ($assignment->actif) {
                        $this->assertGradesEditable($evaluation);
                    }
                    $classStudent = $classStudents->get($matricule);
                    $studentName = $classStudent === null
                        ? trim($row['nom'])
                        : trim(($classStudent->prenom ?? '').' '.($classStudent->nom ?? ''));
                    $observation = $classStudent === null
                        ? 'Étudiant non inscrit dans la base de cette classe; note conservée comme observation à vérifier par l’agent.'
                        : 'Étudiant inscrit dans la classe, mais sans inscription validée à cette UE; note conservée hors calcul et signalée à l’agent.';
                    $existing = DB::table('gnu.note_hors_compte')->where('evaluation_id', $evaluation)
                        ->whereRaw('upper(matricule) = ?', [$matricule])->lockForUpdate()->first();
                    $expectedVersion = (int) ($row['version_note'] ?? 0);
                    abort_if((int) ($existing->version_note ?? 0) !== $expectedVersion, 409, 'La note de l’étudiant importé a changé. Rechargez le carnet avant de continuer.');
                    $values = [
                        'valeur_note' => $row['situation'] === 'NUMERIQUE' ? $row['valeur_note'] : null,
                        'situation' => $row['situation'],
                        'statut_note' => 'BROUILLON',
                        'nom' => $studentName !== '' ? $studentName : trim($row['nom']),
                        'observation' => $observation,
                        'updated_at' => now(),
                    ];
                    if ($existing === null) {
                        DB::table('gnu.note_hors_compte')->insert($values + [
                            'classe_id' => $assignment->classe_id,
                            'ue_id' => $assignment->ue_id,
                            'evaluation_id' => $evaluation,
                            'affectation_id' => $affectation,
                            'matricule' => $matricule,
                            'version_note' => 1,
                            'cree_par' => $request->user()->id,
                            'created_at' => now(),
                        ]);
                    } else {
                        DB::table('gnu.note_hors_compte')->where('id', $existing->id)
                            ->update($values + ['version_note' => $expectedVersion]);
                    }
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
            'notes.*.valeur_note' => ['nullable', 'numeric'],
            'notes.*.version_note' => ['nullable', 'integer', 'min:1'],
        ]));
        $data = $this->clampGradeInputs($data);
        $teacherId = $this->teacherId($request);
        $assignment = $this->ownedAssignment($affectation, $teacherId);
        $this->assertCanonicalGradeAssignment($assignment);
        $officialProfile = DB::table('gnu.profil_evaluation_ue')->where('ue_id', $assignment->ue_id)->value('code_profil');
        if ($officialProfile === null) {
            $proposal = DB::table('gnu.proposition_profil_evaluation')
                ->where('ue_id', $assignment->ue_id)->where('enseignant_id', $assignment->enseignant_id)
                ->where('affectation_id', $assignment->id)->where('statut', 'EN_ATTENTE')
                ->orderByDesc('created_at')->value('code_profil');
            if ($proposal !== null) {
                $this->ensureOfficialPlan($request, $assignment);
            }
        }
        $provisionalEvaluations = $officialProfile === null
            ? DB::table('gnu.proposition_profil_evaluation as pp')
                ->join('gnu.evaluation as ev', 'ev.affectation_id', '=', 'pp.affectation_id')
                ->join('gnu.ligne_plan as lp', 'lp.evaluation_id', '=', 'ev.id')
                ->join('gnu.plan_evaluation as pe', 'pe.id', '=', 'lp.plan_id')
                ->where('pp.affectation_id', $assignment->id)->where('pp.statut', 'EN_ATTENTE')
                ->where('pe.statut_plan', 'ACTIF')->where('lp.retenue', true)
                ->pluck('ev.id')->map(static fn (mixed $id): int => (int) $id)->all()
            : [];
        abort_if($officialProfile === null && $provisionalEvaluations === [], 409, 'Proposez le barème depuis un classeur Excel pour préparer les notes provisoires.');
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
            $isProvisional = in_array((int) $row['evaluation_id'], $provisionalEvaluations, true);
            $event = $isProvisional
                ? DB::table('gnu.evaluation')->where('id', $row['evaluation_id'])->where('affectation_id', $affectation)->first()
                : $this->activeEvaluation($affectation, (int) $row['evaluation_id']);
            abort_unless($event->mode_evaluation === 'NORMALE', 404, 'Évaluation introuvable.');
            if (! $isProvisional) {
                $this->assertGradesEditable((int) $row['evaluation_id'], (int) $student->inscription_ue_id);
            }
        }

        $saved = DB::transaction(function () use ($request, $data, $assignment, $student, $provisionalEvaluations): int {
            DB::table('gnu.affectation')->where('id', $assignment->id)->lockForUpdate()->first();
            $this->setAuditContext($request, $data['motif']);
            $count = 0;
            foreach ($data['notes'] as $row) {
                $evaluationId = (int) $row['evaluation_id'];
                if (! in_array($evaluationId, $provisionalEvaluations, true)) {
                    $this->assertGradesEditable($evaluationId, (int) $student->inscription_ue_id);
                }
                $this->markEvaluationRealized($evaluationId);
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
                        in_array($evaluationId, $provisionalEvaluations, true) ? 'SAISIE' : 'CORRECTION', (string) ($correctionDecisionId ?? ''),
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
        $this->assertCanonicalGradeAssignment($assignment);
        abort_if(DB::table('gnu.profil_evaluation_ue')->where('ue_id', $assignment->ue_id)->value('code_profil') === null, 409, 'Le barème officiel de cette UE doit être défini et approuvé avant la validation des notes.');
        abort_unless((bool) $assignment->actif, 409, 'L’affectation est en attente d’approbation. Vous pouvez enregistrer vos brouillons, mais la transmission à la cellule sera disponible après approbation.');
        $event = DB::table('gnu.evaluation')->where('id', $evaluation)->where('affectation_id', $affectation)->first();
        abort_unless($event !== null, 404, 'Évaluation introuvable.');
        if ($event->mode_evaluation === 'NORMALE') {
            $this->activeEvaluation($affectation, $evaluation);
        } else {
            abort_unless($event->mode_evaluation === 'RATTRAPAGE' && DB::table('gnu.candidature_rattrapage')
                ->where('evaluation_rattrapage_id', $evaluation)->where('matiere_id', $assignment->matiere_id)
                ->whereIn('statut_candidature', ['AUTORISEE', 'PROGRAMMEE'])->exists(), 404, 'Aucune candidature autorisée pour cette évaluation de rattrapage.');
        }

        $result = DB::transaction(function () use ($request, $data, $evaluation, $affectation, $assignment, $event, $teacherId): array {
            DB::table('gnu.affectation')->where('id', $affectation)->lockForUpdate()->first();
            $current = DB::table('gnu.transmission_note')->where('evaluation_id', $evaluation)->orderByDesc('version')->lockForUpdate()->first();
            $authorizedCorrection = $this->hasPreparedMissingNoteCorrection($evaluation);
            abort_if(
                $current !== null
                    && in_array($current->statut, ['TRANSMISE', 'A_VERIFIER', 'VERIFIEE', 'VALIDEE_ENSEIGNANT', 'PUBLIEE'], true)
                    && ! (in_array($current->statut, ['VERIFIEE', 'PUBLIEE'], true) && $authorizedCorrection),
                409,
                'Cette transmission est déjà validée. Une nouvelle transmission exige une correction de note manquante autorisée.',
            );
            $roster = $event->mode_evaluation === 'RATTRAPAGE'
                ? DB::table('gnu.candidature_rattrapage')->where('evaluation_rattrapage_id', $evaluation)
                    ->where('matiere_id', $assignment->matiere_id)->whereIn('statut_candidature', ['AUTORISEE', 'PROGRAMMEE'])
                    ->whereNull('date_consommation')->pluck('inscription_ue_id')
                : DB::table('gnu.inscription_classe as ic')->join('gnu.inscription_ue as iu', function ($join) use ($assignment): void {
                    $join->on('iu.inscription_classe_id', '=', 'ic.id')->where('iu.ue_id', '=', $assignment->ue_id);
                })->where('ic.classe_id', $assignment->classe_id)->where('ic.statut_inscription', 'VALIDEE')->where('iu.statut_inscription', 'VALIDEE')->pluck('iu.id');
            $externalRows = $event->mode_evaluation === 'NORMALE'
                ? DB::table('gnu.note_hors_compte')->where('evaluation_id', $evaluation)
                    ->where('affectation_id', $affectation)->where('classe_id', $assignment->classe_id)
                    ->orderBy('matricule')->lockForUpdate()->get()
                : collect();
            abort_if($roster->isEmpty() && $externalRows->isEmpty(), 409, 'Aucun étudiant inscrit ou importé dans cette évaluation.');
            abort_if($externalRows->contains(static fn (object $row): bool => $row->situation === 'MANQUANTE'), 409, 'Complétez la note ou indiquez explicitement EL pour chaque étudiant ajouté hors compte avant la transmission.');
            $this->setAuditContext($request, $data['motif']);
            $elCount = 0;
            $existingNotes = DB::table('gnu.note')->where('evaluation_id', $evaluation)
                ->whereIn('inscription_ue_id', $roster)->lockForUpdate()->get()
                ->keyBy('inscription_ue_id');
            foreach ($roster as $registrationId) {
                $existing = $existingNotes->get($registrationId);
                if ($existing !== null && $existing->situation !== 'MANQUANTE') {
                    continue;
                }
                $this->assertGradesEditable($evaluation, (int) $registrationId);
                $decisionId = $this->authorizedMissingNoteCorrectionDecisionId($evaluation, (int) $registrationId);
                DB::select("SELECT set_config('gnu.origine', ?, true), set_config('gnu.decision_id', ?, true)", [
                    $decisionId !== null ? 'CORRECTION' : 'SAISIE',
                    (string) ($decisionId ?? ''),
                ]);
                if ($existing === null) {
                    DB::table('gnu.note')->insert([
                        'evaluation_id' => $evaluation,
                        'inscription_ue_id' => $registrationId,
                        'valeur_note' => null,
                        'situation' => 'ABSENTE',
                        'statut_note' => 'BROUILLON',
                        'version_note' => 1,
                        'validateur_id' => null,
                        'date_validation' => null,
                        'created_at' => now(),
                        'updated_at' => now(),
                    ]);
                } else {
                    DB::table('gnu.note')->where('id', $existing->id)->update([
                        'valeur_note' => null,
                        'situation' => 'ABSENTE',
                        'statut_note' => 'BROUILLON',
                        'version_note' => $existing->version_note,
                        'validateur_id' => null,
                        'date_validation' => null,
                        'updated_at' => now(),
                    ]);
                }
                $elCount++;
            }
            $completed = DB::table('gnu.note')->where('evaluation_id', $evaluation)->whereIn('inscription_ue_id', $roster)
                ->whereIn('statut_note', ['BROUILLON', 'VALIDEE'])->whereIn('situation', ['NUMERIQUE', 'ABSENTE'])->count();
            abort_unless($completed === $roster->count(), 409, 'Complétez une note numérique pour chaque étudiant inscrit ou candidat avant la transmission.');
            DB::select("SELECT set_config('gnu.origine', ?, true), set_config('gnu.decision_id', '', true)", ['TRANSMISSION']);
            DB::table('gnu.note')->where('evaluation_id', $evaluation)->whereIn('inscription_ue_id', $roster)
                ->whereIn('situation', ['NUMERIQUE', 'ABSENTE'])->update([
                    'statut_note' => 'BROUILLON',
                    'validateur_id' => null,
                    'date_validation' => null,
                    'updated_at' => now(),
                ]);
            if ($externalRows->isNotEmpty()) {
                DB::table('gnu.note_hors_compte')->whereIn('id', $externalRows->pluck('id')->all())->update([
                    'statut_note' => 'BROUILLON',
                    'updated_at' => now(),
                ]);
            }

            $id = (int) DB::table('gnu.transmission_note')->insertGetId([
                'evaluation_id' => $evaluation,
                'affectation_id' => $affectation,
                'version' => (int) ($current->version ?? 0) + 1,
                'statut' => 'TRANSMISE',
                'enseignant_id' => $teacherId,
                'transmis_par' => $request->user()->id,
                'transmis_le' => now(),
                'verifie_par' => null,
                'verifie_le' => null,
                'motif' => trim($data['motif']),
                'created_at' => now(),
                'updated_at' => now(),
            ], 'id');
            foreach ($externalRows as $externalRow) {
                DB::table('gnu.transmission_note_hors_compte')->insert([
                    'transmission_id' => $id,
                    'note_hors_compte_id' => $externalRow->id,
                    'matricule' => $externalRow->matricule,
                    'nom' => $externalRow->nom,
                    'valeur_note' => $externalRow->valeur_note,
                    'situation' => $externalRow->situation,
                    'version_note_source' => $externalRow->version_note,
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);
            }

            $this->notifyGradeTransmissionAgents(
                (object) ['id' => $id, 'affectation_id' => $affectation, 'evaluation_id' => $evaluation],
                'TRANSMISSION',
                'Grille de notes transmise à la cellule',
                'La grille attend sa numérisation et le traitement du PV par l’agent. '.$externalRows->count().' étudiant(s) non inscrit(s) sont conservés comme observations.',
            );

            return ['id' => $id, 'mentions_el' => $elCount, 'hors_classe' => $externalRows->count()];
        });

        return response()->json([
            'id' => $result['id'],
            'transmises' => true,
            'message' => 'Notes transmises à la cellule pour numérisation et traitement du PV.'.($result['hors_classe'] > 0 ? ' '.$result['hors_classe'].' étudiant(s) non inscrit(s) ont été conservés comme observations.' : '').($result['mentions_el'] > 0 ? ' '.$result['mentions_el'].' note(s) vide(s) ont été enregistrées avec la mention EL.' : ''),
        ]);
    }

    public function removeGrade(Request $request, int $affectation, int $note): JsonResponse
    {
        $data = $this->normalizeOptionalMotif($request->validate([
            'motif' => ['nullable', 'string', 'min:8', 'max:1000'],
            'version_note' => ['required', 'integer', 'min:1'],
        ]));
        $teacherId = $this->teacherId($request);
        $this->assertCanonicalGradeAssignment($this->ownedAssignment($affectation, $teacherId));
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

    public function exportGradebook(Request $request, int $affectation): mixed
    {
        $teacherId = $this->teacherId($request);
        $assignment = $this->ownedAssignment($affectation, $teacherId);
        $this->assertCanonicalGradeAssignment($assignment);
        $book = $this->gradebook($request, $affectation)->getData(true)['data'];
        $class = DB::table('gnu.classe as c')->join('gnu.niveau as n', 'n.id', '=', 'c.niveau_id')
            ->join('gnu.annee_academique as an', 'an.id', '=', 'c.annee_id')
            ->where('c.id', $assignment->classe_id)->first(['c.code_classe', 'n.code_niv', 'n.libelle_niv', 'an.libelle as annee_academique']);
        abort_unless($class !== null, 404, 'Classe introuvable.');
        $roster = DB::table('gnu.inscription_classe as ic')
            ->join('gnu.etudiant as e', 'e.id', '=', 'ic.etudiant_id')
            ->join('gnu.utilisateur as u', 'u.id', '=', 'e.utilisateur_id')
            ->join('gnu.inscription_ue as iu', function ($join) use ($assignment): void {
                $join->on('iu.inscription_classe_id', '=', 'ic.id')->where('iu.ue_id', '=', $assignment->ue_id);
            })
            ->where('ic.classe_id', $assignment->classe_id)->where('ic.statut_inscription', 'VALIDEE')
            ->where('iu.statut_inscription', 'VALIDEE')->get(['e.matricule', 'u.nom', 'u.prenom'])
            ->keyBy(static fn (object $student): string => mb_strtoupper(trim($student->matricule)));

        $evaluations = $book['plan']['composantes'] ?? [];
        $proposedProfile = null;
        if ($evaluations === []) {
            $proposedProfile = DB::table('gnu.profil_evaluation_ue')->where('ue_id', $assignment->ue_id)->value('code_profil')
                ?? DB::table('gnu.proposition_profil_evaluation')
                    ->where('ue_id', $assignment->ue_id)
                    ->where('enseignant_id', $assignment->enseignant_id)
                    ->where('affectation_id', $assignment->id)
                    ->whereIn('statut', ['EN_ATTENTE', 'APPROUVEE'])
                    ->orderByDesc('created_at')
                    ->value('code_profil');
            if ($proposedProfile !== null) {
                $weights = $this->weightsForProfile($proposedProfile);
                foreach ($weights as $type => $weight) {
                    $evaluations[] = [
                        'type_eval' => $type,
                        'poids_evaluation' => $weight,
                    ];
                }
            }
        }
        $headers = ['Matricule', 'Nom', 'Prénom', 'Classe', 'Niveau', 'Année académique', 'UE'];
        $evaluationHeaders = [];
        $occurrences = [];
        foreach ($evaluations as $evaluation) {
            $type = mb_strtoupper((string) $evaluation['type_eval']);
            $occurrences[$type] = ($occurrences[$type] ?? 0) + 1;
            $header = $type.'_'.$occurrences[$type];
            $headers[] = $header;
            $evaluationHeaders[] = [
                'evaluation_id' => isset($evaluation['evaluation_id']) ? (int) $evaluation['evaluation_id'] : null,
                'header' => $header,
            ];
        }
        $gridOccurrences = [];
        $gridDescription = [];
        foreach ($evaluations as $evaluation) {
            $type = mb_strtoupper((string) $evaluation['type_eval']);
            $gridOccurrences[$type] = ($gridOccurrences[$type] ?? 0) + 1;
            $gridDescription[] = $type.'_'.$gridOccurrences[$type].' ('.$evaluation['poids_evaluation'].' %)';
        }

        $rows = [$headers];
        foreach ($book['etudiants'] ?? [] as $student) {
            $matricule = mb_strtoupper(trim((string) $student['matricule']));
            $identity = $roster->get($matricule);
            if ($identity === null) {
                continue;
            }
            $notesByEvaluation = collect($student['notes'] ?? [])->keyBy('evaluation_id');
            $row = [
                (string) $identity->matricule,
                $identity->nom,
                $identity->prenom,
                $class->code_classe,
                $class->code_niv.' · '.$class->libelle_niv,
                $class->annee_academique,
                $assignment->code_ue,
            ];
            foreach ($evaluationHeaders as $column) {
                $note = $column['evaluation_id'] === null ? null : $notesByEvaluation->get($column['evaluation_id']);
                $row[] = ($note['situation'] ?? null) === 'ABSENTE'
                    ? 'ABS'
                    : (($note['valeur_note'] ?? null) === null ? '' : (float) $note['valeur_note']);
            }
            $rows[] = $row;
        }
        $content = app(GradeWorkbookWriter::class)->write([
            ['name' => 'Notes', 'rows' => $rows],
            ['name' => 'Consignes', 'rows' => [
                ['Modèle de notes GNU'],
                ['La feuille Notes affiche les évaluations communes de cette UE (CC, TP ou TPE, SN). Une seule colonne est prévue par type d’évaluation.'],
                ['Grille appliquée : '.implode(' · ', $gridDescription)],
                ['Matricule, nom, prénom, classe, niveau et année académique identifient et vérifient l’étudiant. Ne modifiez pas ces colonnes.'],
                ['Saisissez une note de 0 à 20 dans chaque colonne CC_1, TP_1, TPE_1, SN_1 affichée. Les colonnes présentes dépendent de la grille configurée. Utilisez une virgule ou un point pour les décimales.'],
                ['Laissez la cellule vide si la note n’est pas encore saisie. Utilisez ABS ou EL uniquement pour signaler une absence.'],
                ['À l’importation, chaque étudiant, classe, niveau et valeur est contrôlé. Les notes sont enregistrées en brouillon.'],
                ['Transmettez ensuite chaque évaluation à la cellule informatique pour contrôle et validation.'],
                ...($proposedProfile === null ? [] : [['Profil proposé par l’enseignant : '.$proposedProfile.'. Les notes peuvent être préparées en brouillon; la transmission officielle reste bloquée jusqu’à validation par la cellule.']]),
            ]],
        ]);
        $filename = 'modele-notes-'.$this->safeFilename($class->code_classe.'-'.$assignment->code_ue).'.xlsx';

        return response()->streamDownload(static function () use ($content): void {
            echo $content;
        }, $filename, ['Content-Type' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet']);
    }

    public function exportEvaluationGradeTemplate(Request $request, int $affectation, int $evaluation): mixed
    {
        $teacherId = $this->teacherId($request);
        $assignment = $this->ownedAssignment($affectation, $teacherId);
        $this->assertCanonicalGradeAssignment($assignment);
        $event = DB::table('gnu.evaluation')->where('id', $evaluation)->where('affectation_id', $affectation)->first(['type_eval']);
        abort_unless($event !== null, 404, 'Évaluation introuvable.');
        $book = $this->gradebook($request, $affectation)->getData(true)['data'];
        $rows = [['Nom', 'Matricule', 'Note/20']];
        foreach ($book['etudiants'] as $student) {
            $note = collect($student['notes'] ?? [])->firstWhere('evaluation_id', $evaluation);
            $rows[] = [
                $student['nom'] ?? '',
                $student['matricule'] ?? '',
                ($note['situation'] ?? null) === 'NUMERIQUE' ? (float) $note['valeur_note'] : '',
            ];
        }
        $content = app(GradeWorkbookWriter::class)->write([
            ['name' => mb_strtoupper((string) $event->type_eval), 'rows' => $rows],
        ]);
        $filename = 'modele-'.$this->safeFilename($assignment->code_classe.'-'.$assignment->code_ue.'-'.$assignment->code_m.'-'.$event->type_eval).'.xlsx';

        return response()->streamDownload(static function () use ($content): void {
            echo $content;
        }, $filename, ['Content-Type' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet']);
    }

    public function previewEvaluationGradeImport(Request $request, int $affectation, int $evaluation): JsonResponse
    {
        $request->validate(['fichier' => ['required', 'file', 'mimes:xlsx,csv,txt', 'max:10240']]);
        $teacherId = $this->teacherId($request);
        $assignment = $this->ownedAssignment($affectation, $teacherId);
        $this->assertCanonicalGradeAssignment($assignment);
        $event = DB::table('gnu.evaluation as ev')
            ->leftJoin('gnu.ligne_plan as lp', 'lp.evaluation_id', '=', 'ev.id')
            ->where('ev.id', $evaluation)->where('ev.affectation_id', $affectation)
            ->first(['ev.id', 'ev.type_eval', 'lp.poids_evaluation', 'ev.date_evaluation', 'ev.mode_evaluation']);
        abort_unless($event !== null && $event->mode_evaluation === 'NORMALE', 404, 'Évaluation introuvable.');
        if ($assignment->actif) {
            $this->assertGradesEditable($evaluation);
        }
        $table = app(GradeSpreadsheetReader::class)->readTable($request->file('fichier'));
        $nameIndex = $this->findSpreadsheetHeader($table['headers'], ['nom', 'noms', 'nom_et_prenom', 'nom_et_prenoms', 'etudiant']);
        $matriculeIndex = $this->findSpreadsheetHeader($table['headers'], ['matricule', 'matricule_etudiant']);
        $noteIndex = $this->findSpreadsheetHeader($table['headers'], ['note', 'note_20', 'note_sur_20', 'valeur_note', 'grade']);
        $missing = array_filter(['Nom' => $nameIndex, 'Matricule' => $matriculeIndex, 'Note/20' => $noteIndex], static fn (?int $index): bool => $index === null);
        if ($missing !== []) {
            throw ValidationException::withMessages(['fichier' => ['Le modèle doit contenir les colonnes Nom, Matricule et Note/20.']]);
        }

        $book = $this->gradebook($request, $affectation)->getData(true)['data'];
        $students = collect($book['etudiants'])->keyBy(static fn (array $student): string => mb_strtoupper(trim((string) $student['matricule'])));
        $seen = [];
        $notes = [];
        $errors = [];
        $bounded = 0;
        foreach ($table['rows'] as $index => $row) {
            $line = $index + 2;
            $matricule = mb_strtoupper(trim((string) ($row[$matriculeIndex] ?? '')));
            $sourceName = trim((string) ($row[$nameIndex] ?? ''));
            $raw = trim((string) ($row[$noteIndex] ?? ''));
            if ($matricule === '' && $sourceName === '' && $raw === '') {
                continue;
            }
            if ($matricule === '' || $sourceName === '') {
                $errors[] = ['ligne' => $line, 'message' => 'Le nom et le matricule sont obligatoires.'];

                continue;
            }
            if (isset($seen[$matricule])) {
                $errors[] = ['ligne' => $line, 'message' => 'Matricule présent plusieurs fois dans le fichier.'];

                continue;
            }
            $seen[$matricule] = true;
            $student = $students->get($matricule);
            $situation = match (mb_strtoupper($raw)) {
                '', 'MANQUANTE', 'MANQUANT' => 'MANQUANTE',
                'ABS', 'ABSENT', 'ABSENTE', 'EL', 'ELIMINE', 'ELIMINEE' => 'ABSENTE',
                default => 'NUMERIQUE',
            };
            $value = null;
            if ($situation === 'NUMERIQUE') {
                $normalized = str_replace(',', '.', $raw);
                if (! is_numeric($normalized)) {
                    $errors[] = ['ligne' => $line, 'message' => 'La note doit être numérique, vide, ABS ou EL.'];

                    continue;
                }
                $number = (float) $normalized;
                $value = min(20.0, max(0.0, $number));
                if ($value !== $number) {
                    $bounded++;
                }
            }
            $currentNote = $student === null ? null : collect($student['notes'])->firstWhere('evaluation_id', $evaluation);
            $outsideRosterObservation = $student === null
                ? 'Non inscrit dans la classe ou l’UE; la note sera conservée hors calcul et signalée à l’agent.'
                : ($student['observation'] ?? 'Étudiant sans inscription active à cette UE; à vérifier par l’agent.');
            $notes[] = [
                'matricule' => $matricule,
                'nom' => $student['nom'] ?? $sourceName,
                'valeur_note' => $value,
                'situation' => $situation,
                'version_note' => $currentNote['version_note'] ?? null,
                'hors_compte' => $student === null || ($student['hors_compte'] ?? false) === true,
                'observation' => $student === null || ($student['hors_compte'] ?? false) === true
                    ? $outsideRosterObservation
                    : null,
            ];
        }

        $class = DB::table('gnu.classe as c')->join('gnu.niveau as n', 'n.id', '=', 'c.niveau_id')
            ->leftJoin('gnu.specialite as sp', 'sp.id', '=', 'n.specialite_id')->where('c.id', $assignment->classe_id)
            ->first(['c.code_classe', 'n.libelle_niv', 'sp.libelle_specialite']);

        return response()->json(['data' => [
            'classe' => $class?->code_classe,
            'niveau' => $class?->libelle_niv,
            'specialite' => $class?->libelle_specialite,
            'code_ue' => $assignment->code_ue,
            'code_ec' => $assignment->code_m,
            'evaluation' => $event->type_eval,
            'poids' => (float) $event->poids_evaluation,
            'date_evaluation' => $event->date_evaluation,
            'notes' => $notes,
            'erreurs' => $errors,
            'importables' => count($notes),
            'total' => count($table['rows']),
            'notes_bornees' => $bounded,
        ]]);
    }

    public function importGrades(Request $request, int $affectation, int $evaluation): JsonResponse
    {
        $request->validate(['fichier' => ['required', 'file', 'mimes:xlsx,csv,txt', 'max:10240']]);
        $teacherId = $this->teacherId($request);
        $assignment = $this->ownedAssignment($affectation, $teacherId);
        $this->assertCanonicalGradeAssignment($assignment);
        $event = $this->activeEvaluation($affectation, $evaluation);
        if ($assignment->actif) {
            $this->assertGradesEditable($evaluation);
        }
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
        $clampedScores = 0;
        $elMarkers = 0;
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
            $rawMark = mb_strtoupper($raw);
            $situation = $raw === ''
                ? 'MANQUANTE'
                : match ($declaredSituation) {
                    'NUMERIQUE' => 'NUMERIQUE',
                    'ABS', 'ABSENT', 'ABSENTE', 'EL', 'ELIMINE', 'ELIMINEE' => 'ABSENTE',
                    'MANQUANTE', 'MANQUANT' => 'MANQUANTE',
                    '' => match ($rawMark) {
                        'ABS', 'ABSENT', 'ABSENTE', 'EL', 'ELIMINE', 'ELIMINEE' => 'ABSENTE',
                        'MANQUANTE', 'MANQUANT' => 'MANQUANTE',
                        default => 'NUMERIQUE',
                    },
                    default => null,
                };
            if ($situation === null) {
                $errors[] = ['ligne' => $line, 'message' => 'La situation doit être NUMERIQUE, ABSENTE ou MANQUANTE.'];

                continue;
            }
            $value = $situation === 'NUMERIQUE' ? str_replace(',', '.', $raw) : null;
            if ($situation === 'NUMERIQUE') {
                if (! is_numeric($value)) {
                    $errors[] = ['ligne' => $line, 'message' => 'La note doit être numérique, ou indiquée ABS/EL.'];

                    continue;
                }
                $numericValue = (float) $value;
                $boundedValue = min(20.0, max(0.0, $numericValue));
                if ($boundedValue !== $numericValue) {
                    $clampedScores++;
                }
                $value = $boundedValue;
            }
            if ($situation === 'ABSENTE') {
                $elMarkers++;
            }
            $student = $students[$matricule];
            $rows[] = [
                'matricule' => $matricule,
                'situation' => $situation,
                'valeur_note' => $value === null ? null : (float) $value,
                'version_note' => $student->version_note === null ? null : (int) $student->version_note,
            ];
        }

        return response()->json(['data' => [
            'notes' => $rows,
            'erreurs' => $errors,
            'importables' => count($rows),
            'total' => count($parsed),
            'notes_bornees' => $clampedScores,
            'mentions_el' => $elMarkers,
        ]]);
    }

    public function previewGradebookImport(Request $request, int $affectation): JsonResponse
    {
        $request->validate(['fichier' => ['required', 'file', 'mimes:xlsx,csv,txt', 'max:10240']]);
        $teacherId = $this->teacherId($request);
        $assignment = $this->ownedAssignment($affectation, $teacherId);
        $this->assertCanonicalGradeAssignment($assignment);
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
        $evaluationTypes = array_column($columns, 'type_eval');
        abort_if(
            count($evaluationTypes) !== count(array_unique($evaluationTypes)),
            422,
            'Le modèle doit contenir une seule colonne par type d’évaluation pour cette UE.',
        );
        $identityColumns = [
            'matricule' => $this->findSpreadsheetHeader($table['headers'], ['matricule', 'matricule_etudiant']),
            'nom' => $this->findSpreadsheetHeader($table['headers'], ['nom', 'nom_etudiant', 'nom_de_famille']),
            'prenom' => $this->findSpreadsheetHeader($table['headers'], ['prenom', 'prenom_etudiant']),
            'classe' => $this->findSpreadsheetHeader($table['headers'], ['classe', 'code_classe', 'classe_etudiant']),
            'niveau' => $this->findSpreadsheetHeader($table['headers'], ['niveau', 'code_niveau', 'niveau_etudiant', 'niveau_de_l_etudiant']),
        ];
        $academicYearColumn = $this->findSpreadsheetHeader($table['headers'], ['annee', 'annee_academique', 'annee_scolaire']);
        $unitColumn = $this->findSpreadsheetHeader($table['headers'], ['ue', 'code_ue', 'unite_enseignement']);
        $elementColumn = $this->findSpreadsheetHeader($table['headers'], ['ec', 'code_ec', 'code_m', 'element_constitutif']);
        $missingIdentity = array_keys(array_filter($identityColumns, static fn (?int $index): bool => $index === null));
        if ($missingIdentity !== []) {
            throw ValidationException::withMessages(['fichier' => ['Le modèle Excel doit contenir les colonnes Matricule, Nom, Prénom, Classe et Niveau. Colonnes manquantes : '.implode(', ', $missingIdentity).'.']]);
        }

        $class = DB::table('gnu.classe as c')->join('gnu.niveau as n', 'n.id', '=', 'c.niveau_id')
            ->join('gnu.annee_academique as an', 'an.id', '=', 'c.annee_id')
            ->where('c.id', $assignment->classe_id)->first(['c.code_classe', 'n.code_niv', 'n.libelle_niv', 'an.libelle as annee_academique']);
        $classRoster = DB::table('gnu.inscription_classe as ic')
            ->join('gnu.etudiant as e', 'e.id', '=', 'ic.etudiant_id')
            ->leftJoin('gnu.utilisateur as u', 'u.id', '=', 'e.utilisateur_id')
            ->where('ic.classe_id', $assignment->classe_id)
            ->where('ic.statut_inscription', 'VALIDEE')
            ->get(['e.matricule', 'u.nom', 'u.prenom'])
            ->keyBy(fn (object $student): string => mb_strtoupper(trim($student->matricule)));
        $roster = DB::table('gnu.inscription_classe as ic')
            ->join('gnu.etudiant as e', 'e.id', '=', 'ic.etudiant_id')
            ->join('gnu.inscription_ue as iu', function ($join) use ($assignment): void {
                $join->on('iu.inscription_classe_id', '=', 'ic.id')->where('iu.ue_id', '=', $assignment->ue_id);
            })
            ->where('ic.classe_id', $assignment->classe_id)
            ->where('ic.statut_inscription', 'VALIDEE')
            ->where('iu.statut_inscription', 'VALIDEE')
            ->get(['e.matricule'])
            ->keyBy(fn (object $student): string => mb_strtoupper(trim($student->matricule)));

        $importable = [];
        $errors = [];
        $seen = [];
        $clampedScores = 0;
        $elMarkers = 0;
        foreach ($table['rows'] as $index => $row) {
            $line = $index + 2;
            $matricule = strtoupper(trim((string) ($row[$matriculeIndex] ?? '')));
            if ($matricule === '') {
                $errors[] = ['ligne' => $line, 'message' => 'Matricule manquant.'];

                continue;
            }
            if (isset($seen[$matricule])) {
                $errors[] = ['ligne' => $line, 'message' => 'Matricule présent plusieurs fois dans le fichier.'];

                continue;
            }
            $seen[$matricule] = true;
            $classStudent = $classRoster->get($matricule);
            $student = $roster->get($matricule);
            $provided = [
                'nom' => trim((string) ($row[$identityColumns['nom']] ?? '')),
                'prenom' => trim((string) ($row[$identityColumns['prenom']] ?? '')),
                'classe' => trim((string) ($row[$identityColumns['classe']] ?? '')),
                'niveau' => trim((string) ($row[$identityColumns['niveau']] ?? '')),
            ];
            $targetMatches = $this->normalizeSpreadsheetIdentity($provided['classe'])
                    === $this->normalizeSpreadsheetIdentity($class->code_classe)
                && in_array($this->normalizeSpreadsheetIdentity($provided['niveau']), [
                    $this->normalizeSpreadsheetIdentity($class->code_niv),
                    $this->normalizeSpreadsheetIdentity($class->libelle_niv),
                    $this->normalizeSpreadsheetIdentity($class->code_niv.' '.$class->libelle_niv),
                ], true);
            if ($unitColumn !== null) {
                $targetMatches = $targetMatches
                    && $this->normalizeSpreadsheetIdentity((string) ($row[$unitColumn] ?? '')) === $this->normalizeSpreadsheetIdentity($assignment->code_ue);
            }
            if ($elementColumn !== null) {
                $targetMatches = $targetMatches
                    && $this->normalizeSpreadsheetIdentity((string) ($row[$elementColumn] ?? '')) === $this->normalizeSpreadsheetIdentity($assignment->code_m);
            }
            if ($academicYearColumn !== null) {
                $targetMatches = $targetMatches
                    && $this->normalizeSpreadsheetIdentity((string) ($row[$academicYearColumn] ?? '')) === $this->normalizeSpreadsheetIdentity($class->annee_academique);
            }
            if (! $targetMatches) {
                $errors[] = ['ligne' => $line, 'message' => 'La ligne ne correspond pas à la classe, à l’UE, à l’EC ou à l’année sélectionnée.'];

                continue;
            }
            if ($classStudent === null && trim($provided['nom'].' '.$provided['prenom']) === '') {
                $errors[] = ['ligne' => $line, 'message' => 'Nom et prénom obligatoires pour conserver un étudiant non inscrit.'];

                continue;
            }
            $fullName = $classStudent === null
                ? trim($provided['prenom'].' '.$provided['nom'])
                : trim(($classStudent->prenom ?? '').' '.($classStudent->nom ?? ''));
            if (mb_strlen($fullName) > 180) {
                $errors[] = ['ligne' => $line, 'message' => 'Le nom complet dépasse la limite de 180 caractères.'];

                continue;
            }
            $nameMismatch = $classStudent !== null
                && ($this->normalizeSpreadsheetIdentity($provided['nom']) !== $this->normalizeSpreadsheetIdentity((string) $classStudent->nom)
                    || $this->normalizeSpreadsheetIdentity($provided['prenom']) !== $this->normalizeSpreadsheetIdentity((string) $classStudent->prenom));
            $observation = $student === null
                ? ($classStudent === null
                    ? 'Non inscrit dans la base de cette classe; la note sera conservée comme observation à vérifier par l’agent.'
                    : 'Inscrit dans la classe, mais sans inscription validée à cette UE; à vérifier par l’agent.')
                : ($nameMismatch ? 'Le nom ou le prénom du fichier diffère de la fiche d’inscription; matricule utilisé pour le rapprochement.' : null);
            $marks = [];
            $rowValid = true;
            foreach ($columns as $column) {
                $raw = trim((string) ($row[$column['index']] ?? ''));
                $token = mb_strtoupper($raw);
                if ($raw === '' || in_array($token, ['MANQUANTE', 'MANQUANT'], true)) {
                    $marks[] = $column + ['situation' => 'MANQUANTE', 'valeur_note' => null];

                    continue;
                }
                if (in_array($token, ['ABS', 'ABSENT', 'ABSENTE', 'EL', 'ELIMINE', 'ELIMINEE'], true)) {
                    $marks[] = $column + ['situation' => 'ABSENTE', 'valeur_note' => null];
                    $elMarkers++;

                    continue;
                }
                $value = str_replace(',', '.', $raw);
                if (! is_numeric($value)) {
                    $errors[] = ['ligne' => $line, 'message' => 'La note '.$column['entete'].' doit être numérique, ou indiquée ABS/EL.'];
                    $rowValid = false;

                    continue;
                }
                $numericValue = (float) $value;
                $boundedValue = min(20.0, max(0.0, $numericValue));
                if ($boundedValue !== $numericValue) {
                    $clampedScores++;
                }
                $marks[] = $column + ['situation' => 'NUMERIQUE', 'valeur_note' => $boundedValue];
            }
            if ($rowValid && $marks !== []) {
                $importable[] = [
                    'matricule' => $matricule,
                    'nom' => $classStudent === null ? $provided['nom'] : (string) ($classStudent->nom ?? ''),
                    'prenom' => $classStudent === null ? $provided['prenom'] : (string) ($classStudent->prenom ?? ''),
                    'nom_complet' => $fullName,
                    'inscrit_ue' => $student !== null,
                    'observation' => $observation,
                    'notes' => $marks,
                ];
            }
        }

        $planComponents = $this->planData($affectation, $teacherId)['composantes'];
        $weights = [];
        if ($planComponents !== []) {
            if (count($columns) !== count($planComponents)) {
                throw ValidationException::withMessages(['fichier' => ['Les colonnes du fichier ne correspondent pas au nombre de composantes de la grille active. Téléchargez un modèle récent.']]);
            }
            $occurrences = [];
            foreach ($planComponents as $index => $component) {
                $type = mb_strtoupper((string) $component['type_eval']);
                $occurrences[$type] = ($occurrences[$type] ?? 0) + 1;
                $expectedHeader = strtolower($type.'_'.$occurrences[$type]);
                if ($columns[$index]['entete'] !== $expectedHeader || $columns[$index]['type_eval'] !== $type) {
                    throw ValidationException::withMessages(['fichier' => ['La colonne '.$columns[$index]['entete'].' ne correspond pas à la grille active. Téléchargez un modèle récent.']]);
                }
                $columns[$index]['evaluation_id'] = (int) $component['evaluation_id'];
                $columns[$index]['poids_evaluation'] = (float) $component['poids_evaluation'];
                $weights[$type] = ($weights[$type] ?? 0.0) + (float) $component['poids_evaluation'];
            }
        } else {
            $profile = $assignment->profil_evaluation
                ?? DB::table('gnu.proposition_profil_evaluation')
                    ->where('ue_id', $assignment->ue_id)
                    ->where('enseignant_id', $assignment->enseignant_id)
                    ->where('affectation_id', $assignment->id)
                    ->whereIn('statut', ['EN_ATTENTE', 'APPROUVEE'])
                    ->orderByDesc('created_at')
                    ->value('code_profil');
            $weights = $profile === null ? [] : $this->weightsForProfile($profile);
            $expectedTypes = array_keys($weights);
            if ($expectedTypes === [] || count($columns) !== count($expectedTypes)) {
                throw ValidationException::withMessages(['fichier' => ['La grille d’évaluation n’est pas encore définie ou le fichier ne correspond pas au modèle.']]);
            }
            foreach ($expectedTypes as $index => $type) {
                $expectedHeader = strtolower($type.'_1');
                if ($columns[$index]['entete'] !== $expectedHeader || $columns[$index]['type_eval'] !== $type) {
                    throw ValidationException::withMessages(['fichier' => ['Le fichier ne correspond pas au profil '.$profile.'. Téléchargez le modèle généré depuis cette affectation.']]);
                }
                $columns[$index]['evaluation_id'] = null;
                $columns[$index]['poids_evaluation'] = $weights[$type];
            }
        }

        return response()->json(['data' => [
            'colonnes' => $columns,
            'notes' => $importable,
            'erreurs' => $errors,
            'importables' => count($importable),
            'total' => count($table['rows']),
            'ponderations' => $weights,
            'notes_bornees' => $clampedScores,
            'mentions_el' => $elMarkers,
        ]]);
    }

    /** @param list<string> $headers @param list<string> $aliases */
    private function findSpreadsheetHeader(array $headers, array $aliases): ?int
    {
        foreach ($aliases as $alias) {
            $index = array_search($alias, $headers, true);
            if ($index !== false) {
                return $index;
            }
        }

        return null;
    }

    private function normalizeSpreadsheetIdentity(string $value): string
    {
        $ascii = iconv('UTF-8', 'ASCII//TRANSLIT//IGNORE', trim($value));
        $normalized = mb_strtolower((string) $ascii);

        return preg_replace('/[^a-z0-9]+/', '', $normalized) ?? '';
    }

    private function safeFilename(string $value): string
    {
        $ascii = iconv('UTF-8', 'ASCII//TRANSLIT//IGNORE', $value);

        return trim(preg_replace('/[^A-Za-z0-9._-]+/', '-', (string) $ascii) ?? 'gnu', '-');
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

    public function notifications(Request $request): JsonResponse
    {
        $this->teacherId($request);
        $rows = DB::table('gnu.notification')->where('destinataire_id', $request->user()->id)
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
        abort_unless($updated > 0 || DB::table('gnu.notification')->where('id', $notification)
            ->where('destinataire_id', $request->user()->id)->exists(), 404);

        return response()->json(['message' => 'Notification marquée comme lue.']);
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
                    ->update(['courante' => false]);
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
            ->join('gnu.annee_academique as an', 'an.id', '=', 'c.annee_id')
            ->join('gnu.niveau as n', 'n.id', '=', 'c.niveau_id')
            ->join('gnu.filiere as f', 'f.id', '=', 'n.filiere_id')
            ->join('gnu.departement as d', 'd.id', '=', 'f.departement_id')
            ->join('gnu.faculte as fac', 'fac.id', '=', 'd.faculte_id')
            ->join('gnu.universite as un', 'un.id', '=', 'fac.universite_id')
            ->join('gnu.matiere as m', 'm.id', '=', 'a.matiere_id')
            ->join('gnu.ue as u', 'u.id', '=', 'm.ue_id')
            ->leftJoin('gnu.profil_evaluation_ue as profil', 'profil.ue_id', '=', 'u.id')
            ->join('gnu.responsable_note_ue as rnu', function ($join): void {
                $join->on('rnu.classe_id', '=', 'a.classe_id')->on('rnu.ue_id', '=', 'u.id');
            })
            ->where('a.id', $affectation)->where('rnu.enseignant_id', $teacherId)
            ->where('a.actif', true)
            ->first([
                'a.id', 'a.classe_id', 'a.matiere_id', 'a.enseignant_id', 'a.actif',
                'u.id as ue_id', 'u.code_ue', 'u.intitule_ue', 'u.numero_semestre',
                'm.code_m', 'm.intitule_matiere', 'c.code_classe', 'an.libelle as annee_academique',
                'n.libelle_niv', 'fac.nom_fac', 'd.nom_depart', 'un.nom_univ',
                'd.id as departement_id',
                'profil.code_profil as profil_evaluation',
            ]);
        abort_unless($assignment !== null, 404, 'Affectation introuvable ou inactive.');

        return $assignment;
    }

    private function assertCanonicalGradeAssignment(object $assignment): void
    {
        $canonicalId = DB::table('gnu.affectation as a')
            ->join('gnu.matiere as m', 'm.id', '=', 'a.matiere_id')
            ->join('gnu.responsable_note_ue as rnu', function ($join): void {
                $join->on('rnu.classe_id', '=', 'a.classe_id')
                    ->on('rnu.ue_id', '=', 'm.ue_id')
                    ->on('rnu.enseignant_id', '=', 'a.enseignant_id');
            })
            ->where('a.classe_id', $assignment->classe_id)
            ->where('m.ue_id', $assignment->ue_id)
            ->where('a.actif', true)
            ->orderBy('m.rang_ec')
            ->orderBy('a.id')
            ->value('a.id');

        abort_unless(
            $canonicalId !== null && (int) $canonicalId === (int) $assignment->id,
            409,
            'Cette UE possède un carnet unique. Ouvrez le carnet de l’affectation responsable de l’UE.',
        );
    }

    /** Create a class plan from the approved profile or the teacher's request. */
    private function ensureOfficialPlan(Request $request, object $assignment): void
    {
        $this->assertCanonicalGradeAssignment($assignment);
        $profile = $assignment->profil_evaluation;
        if ($profile === null) {
            $profile = DB::table('gnu.profil_evaluation_ue')->where('ue_id', $assignment->ue_id)->value('code_profil')
                ?? DB::table('gnu.proposition_profil_evaluation')
                    ->where('ue_id', $assignment->ue_id)
                    ->where('enseignant_id', $assignment->enseignant_id)
                    ->where('affectation_id', $assignment->id)
                    ->where('statut', 'EN_ATTENTE')
                    ->orderByDesc('created_at')
                    ->value('code_profil');
        }
        if ($profile === null) {
            return;
        }
        DB::transaction(function () use ($request, $assignment, $profile): void {
            DB::table('gnu.affectation')->where('id', $assignment->id)->lockForUpdate()->first();
            $profileNow = DB::table('gnu.profil_evaluation_ue')
                ->where('ue_id', $assignment->ue_id)->value('code_profil');
            if ($profileNow !== null) {
                $profile = $profileNow;
            }
            $activePlan = DB::table('gnu.plan_evaluation')->where('affectation_id', $assignment->id)
                ->where('portee', 'CLASSE')->where('statut_plan', 'ACTIF')->orderByDesc('version_plan')->first();
            $this->setAuditContext($request, 'Initialisation du carnet à partir du profil officiel de l’UE');
            $weights = $this->weightsForProfile($profile);
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
                $this->notifyGradeTransmissionAgents(
                    $row,
                    'CORRECTION_DEMANDEE',
                    'Correction demandée sur un procès-verbal',
                    trim($data['motif']),
                );

                return;
            }
            $digitized = DB::table('gnu.note_numerisee')->where('transmission_id', $row->id)->lockForUpdate()->get();
            $externalDigitized = DB::table('gnu.note_numerisee_hors_compte as nnh')
                ->join('gnu.note_hors_compte as nh', 'nh.id', '=', 'nnh.note_hors_compte_id')
                ->where('nnh.transmission_id', $row->id)->lock('FOR UPDATE OF nnh')->get(['nnh.*', 'nh.version_note as current_version']);
            $gradeCount = DB::table('gnu.note')->where('evaluation_id', $row->evaluation_id)->count();
            $externalCount = DB::table('gnu.transmission_note_hors_compte')->where('transmission_id', $row->id)->count();
            abort_unless(($gradeCount + $externalCount) > 0 && $digitized->count() === $gradeCount && $externalDigitized->count() === $externalCount, 409, 'La grille n’a pas été entièrement numérisée par la cellule.');
            $editedAfterReturn = DB::table('gnu.note')
                ->where('evaluation_id', $row->evaluation_id)
                ->where('updated_at', '>', $locked->traite_le)
                ->exists();
            abort_if(
                $editedAfterReturn,
                409,
                'Des notes ont été modifiées après le retour du PV. Demandez une correction pour renvoyer la grille à la cellule avant le visa final.',
            );
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
            foreach ($externalDigitized as $digitizedGrade) {
                abort_unless((int) $digitizedGrade->current_version === (int) $digitizedGrade->version_note_source, 409, 'Une note hors compte a changé depuis sa numérisation. Demandez à la cellule de recharger la grille.');
                DB::select("SELECT set_config('gnu.origine', ?, true), set_config('gnu.decision_id', '', true)", ['CORRECTION']);
                DB::table('gnu.note_hors_compte')->where('id', $digitizedGrade->note_hors_compte_id)->update([
                    'valeur_note' => $digitizedGrade->situation === 'NUMERIQUE' ? $digitizedGrade->valeur_note : null,
                    'situation' => $digitizedGrade->situation,
                    'statut_note' => 'VALIDEE',
                    'version_note' => $digitizedGrade->version_note_source,
                    'updated_at' => now(),
                ]);
            }
            // The audit constraint accepts the shared VALIDATION origin.
            DB::select("SELECT set_config('gnu.origine', ?, true), set_config('gnu.decision_id', '', true)", ['VALIDATION']);
            DB::table('gnu.note')->where('evaluation_id', $row->evaluation_id)->where('statut_note', 'BROUILLON')
                ->whereIn('situation', ['NUMERIQUE', 'ABSENTE'])->update([
                    'statut_note' => 'VALIDEE', 'validateur_id' => $request->user()->id, 'date_validation' => now(), 'updated_at' => now(),
                ]);
            DB::table('gnu.transmission_note')->where('id', $row->id)->update([
                'statut' => 'VERIFIEE', 'motif' => trim($data['motif']), 'verifie_par' => $request->user()->id,
                'verifie_le' => now(), 'updated_at' => now(),
            ]);
            $this->notifyGradeTransmissionAgents(
                $row,
                'VISA_ENSEIGNANT',
                'PV vérifié par l’enseignant',
                'Le procès-verbal est prêt pour publication aux étudiants.',
            );
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

    public function downloadGradeTransmissionMinutes(Request $request, int $transmission): mixed
    {
        $teacherId = $this->teacherId($request);
        $row = DB::table('gnu.proces_verbal_note as pv')
            ->join('gnu.transmission_note as tn', 'tn.id', '=', 'pv.transmission_id')
            ->where('tn.id', $transmission)->where('tn.enseignant_id', $teacherId)
            ->whereIn('tn.statut', ['A_VERIFIER', 'A_CORRIGER', 'VERIFIEE'])
            ->first(['pv.chemin_fichier', 'tn.evaluation_id', 'tn.version']);
        abort_unless($row !== null && Storage::disk('local')->exists($row->chemin_fichier), 404, 'Le procès-verbal n’est pas disponible.');
        $type = DB::table('gnu.evaluation')->where('id', $row->evaluation_id)->value('type_eval') ?? 'evaluation';

        return Storage::disk('local')->download($row->chemin_fichier, 'PV-'.$type.'-transmission-'.$transmission.'-v'.$row->version.'.pdf', [
            'Content-Type' => 'application/pdf',
        ]);
    }

    /** @param array<string, mixed> $data
     * @return array<string, mixed>
     */
    private function clampGradeInputs(array $data): array
    {
        foreach ($data['notes'] ?? [] as $index => $row) {
            if (($row['situation'] ?? null) !== 'NUMERIQUE' || ! isset($row['valeur_note']) || ! is_numeric($row['valeur_note'])) {
                continue;
            }

            $data['notes'][$index]['valeur_note'] = min(20.0, max(0.0, (float) $row['valeur_note']));
        }

        return $data;
    }

    private function markEvaluationRealized(int $evaluation): void
    {
        $item = DB::table('gnu.evaluation')->where('id', $evaluation)->lockForUpdate()->first(['statut_evaluation']);
        abort_unless($item !== null, 404, 'Évaluation introuvable.');
        if ($item->statut_evaluation === 'REALISEE') {
            return;
        }

        if (DB::table('gnu.note')->where('evaluation_id', $evaluation)->exists()) {
            return;
        }
        DB::table('gnu.evaluation')->where('id', $evaluation)->update([
            'statut_evaluation' => 'REALISEE',
            'updated_at' => now(),
        ]);
    }

    private function assertGradesEditable(int $evaluation, ?int $inscriptionUE = null): void
    {
        $current = DB::table('gnu.transmission_note')->where('evaluation_id', $evaluation)->orderByDesc('version')->first();
        $authorizedCorrection = $inscriptionUE !== null
            && in_array($current?->statut, ['VERIFIEE', 'PUBLIEE'], true)
            && $this->hasAuthorizedMissingNoteCorrection($evaluation, $inscriptionUE);
        abort_if(
            $current !== null
                && in_array($current->statut, ['TRANSMISE', 'VERIFIEE', 'VALIDEE_ENSEIGNANT', 'PUBLIEE'], true)
                && ! $authorizedCorrection,
            409,
            'Les notes sont verrouillées après leur validation. Une correction doit être autorisée par l’administration.',
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
        $this->assertCanonicalGradeAssignment($assignment);
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
                        'proces_verbal_disponible' => DB::table('gnu.proces_verbal_note')->where('transmission_id', $transmission->id)->exists(),
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

    private function notifyGradeTransmissionAgents(
        object $transmission,
        string $event,
        string $title,
        string $message,
    ): void {
        $context = DB::table('gnu.affectation as a')
            ->join('gnu.classe as c', 'c.id', '=', 'a.classe_id')
            ->join('gnu.niveau as n', 'n.id', '=', 'c.niveau_id')
            ->join('gnu.filiere as f', 'f.id', '=', 'n.filiere_id')
            ->join('gnu.matiere as m', 'm.id', '=', 'a.matiere_id')
            ->join('gnu.ue as ue', 'ue.id', '=', 'm.ue_id')
            ->where('a.id', $transmission->affectation_id)
            ->first(['f.departement_id', 'c.code_classe', 'ue.code_ue', 'm.code_m']);
        if ($context === null) {
            return;
        }
        $typeEvaluation = DB::table('gnu.evaluation')
            ->where('id', $transmission->evaluation_id)
            ->value('type_eval') ?? 'Évaluation';

        $agents = DB::table('gnu.agent_departement as ad')
            ->join('gnu.utilisateur as u', 'u.id', '=', 'ad.agent_id')
            ->where('ad.departement_id', $context->departement_id)
            ->where('u.actif', true)
            ->pluck('u.id');
        foreach ($agents as $agentId) {
            DB::table('gnu.notification')->insertOrIgnore([
                'destinataire_id' => $agentId,
                'evaluation_id' => $transmission->evaluation_id,
                'type_notification' => 'TRANSMISSION_NOTE',
                'cle_evenement' => 'TRANSMISSION|'.$transmission->id.'|'.$event.'|AGENT|'.$agentId,
                'contenu' => json_encode([
                    'titre' => $title,
                    'message' => $context->code_classe.' · '.$context->code_ue.'/'.$context->code_m.' · '.$typeEvaluation.' : '.$message,
                    'transmission_id' => $transmission->id,
                ], JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE),
                'date_envoi' => now(),
                'statut_envoi' => 'ENVOYEE',
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }
    }

    private function setAuditContext(Request $request, string $reason): void
    {
        DB::select("SELECT set_config('gnu.acteur_id', ?, true), set_config('gnu.motif', ?, true)", [(string) $request->user()->id, $reason]);
    }
}
