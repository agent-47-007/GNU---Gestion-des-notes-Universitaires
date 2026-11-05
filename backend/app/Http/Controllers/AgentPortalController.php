<?php

namespace App\Http\Controllers;

use App\Services\AcademicRules;
use App\Services\AgentDepartmentScope;
use App\Services\GradeWorkbookWriter;
use Illuminate\Database\Query\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\ValidationException;
use Throwable;

class AgentPortalController extends Controller
{
    public function __construct(private readonly AgentDepartmentScope $scope) {}

    public function dashboard(Request $request): JsonResponse
    {
        $departments = $this->departmentIds($request);
        $classes = $this->classesQuery($departments)
            ->when($request->filled('annee_id'), fn ($query) => $query->where('c.annee_id', $request->integer('annee_id')));

        return response()->json(['data' => [
            'departements' => DB::table('gnu.departement')->whereIn('id', $departments)->count(),
            'classes' => (clone $classes)->count(),
            'ues_actives' => DB::table('gnu.ue as u')
                ->join('gnu.niveau as n', 'n.id', '=', 'u.niveau_id')
                ->join('gnu.filiere as f', 'f.id', '=', 'n.filiere_id')
                ->whereIn('f.departement_id', $departments)->where('u.statut_catalogue', 'ACTIF')
                ->when($request->filled('annee_id'), fn ($query) => $query->whereExists(function ($subquery) use ($request): void {
                    $subquery->selectRaw('1')->from('gnu.classe as c')->whereColumn('c.niveau_id', 'u.niveau_id')
                        ->where('c.annee_id', $request->integer('annee_id'))->whereColumn('c.version_programme', 'u.version_programme');
                }))->count(),
            'inscriptions_a_examiner' => DB::table('gnu.inscription_semestre as s')
                ->join('gnu.inscription_classe as ic', 'ic.id', '=', 's.inscription_classe_id')
                ->join('gnu.classe as c', 'c.id', '=', 'ic.classe_id')
                ->join('gnu.niveau as n', 'n.id', '=', 'c.niveau_id')
                ->join('gnu.filiere as f', 'f.id', '=', 'n.filiere_id')
                ->whereIn('f.departement_id', $departments)->where('s.statut', 'SOUMISE')
                ->when($request->filled('annee_id'), fn ($query) => $query->where('c.annee_id', $request->integer('annee_id')))->count(),
            'publications' => DB::table('gnu.publication as p')
                ->join('gnu.classe as c', 'c.id', '=', 'p.classe_id')
                ->join('gnu.niveau as n', 'n.id', '=', 'c.niveau_id')
                ->join('gnu.filiere as f', 'f.id', '=', 'n.filiere_id')
                ->whereIn('f.departement_id', $departments)
                ->when($request->filled('annee_id'), fn ($query) => $query->where('c.annee_id', $request->integer('annee_id')))->count(),
            'peut_publier' => true,
            'peut_administrer_publication' => $this->isPublicationAdministrator($request),
        ]]);
    }

    public function classes(Request $request): JsonResponse
    {
        return response()->json(['data' => $this->classesQuery($this->departmentIds($request))
            ->when(! $request->boolean('toutes_annees') && $request->filled('annee_id'), fn ($query) => $query->where('c.annee_id', $request->integer('annee_id')))
            ->orderByDesc('an.date_debut')->orderBy('c.code_classe')->get([
                'c.id', 'c.code_classe', 'c.version_programme', 'n.libelle_niv', 'f.code_f', 'f.nom_f', 'd.nom_depart',
                'fac.code_fac', 'fac.nom_fac', 'un.nom_univ',
                'n.id as niveau_id', 'an.libelle as annee_academique', 'an.id as annee_id',
            ])]);
    }

    public function levels(Request $request): JsonResponse
    {
        $rows = DB::table('gnu.niveau as n')->join('gnu.filiere as f', 'f.id', '=', 'n.filiere_id')
            ->join('gnu.departement as d', 'd.id', '=', 'f.departement_id')
            ->join('gnu.faculte as fac', 'fac.id', '=', 'd.faculte_id')
            ->join('gnu.universite as un', 'un.id', '=', 'fac.universite_id')
            ->leftJoin('gnu.specialite as sp', 'sp.id', '=', 'n.specialite_id')
            ->whereIn('f.departement_id', $this->departmentIds($request))->orderBy('fac.code_fac')->orderBy('d.code_de')->orderBy('f.code_f')->orderBy('n.code_niv')
            ->get([
                'n.id', 'n.code_niv', 'n.libelle_niv', 'n.cycle_niv', 'n.filiere_id', 'n.specialite_id',
                'f.code_f', 'f.nom_f', 'f.departement_id', 'd.code_de', 'd.nom_depart',
                'fac.id as faculte_id', 'fac.code_fac', 'fac.nom_fac', 'un.nom_univ', 'sp.code_specialite', 'sp.libelle_specialite',
            ]);
        abort_unless($class !== null, 404, 'Classe introuvable.');

        return response()->json(['data' => $rows]);
    }

    public function academicStructure(Request $request): JsonResponse
    {
        $departments = $this->departmentIds($request);
        $isAdmin = $this->isPublicationAdministrator($request);
        $managedFacultyIds = DB::table('gnu.departement')->whereIn('id', $departments)->pluck('faculte_id')->map(static fn (mixed $id): int => (int) $id)->all();
        $managedUniversityIds = DB::table('gnu.faculte')->whereIn('id', $managedFacultyIds)->pluck('universite_id')->map(static fn (mixed $id): int => (int) $id)->all();
        $universities = DB::table('gnu.universite as un')->orderBy('un.code_univ')->get(['un.id', 'un.code_univ', 'un.nom_univ'])
            ->map(fn (object $university): array => [
                ...((array) $university),
                'modifiable' => $isAdmin || in_array((int) $university->id, $managedUniversityIds, true),
                'logo' => $this->structureLogo('universite_id', (int) $university->id),
            ]);
        $faculties = DB::table('gnu.faculte as fac')->orderBy('fac.code_fac')->get(['fac.id', 'fac.code_fac', 'fac.nom_fac', 'fac.universite_id'])
            ->map(fn (object $faculty): array => [
                ...((array) $faculty),
                'modifiable' => $isAdmin || in_array((int) $faculty->id, $managedFacultyIds, true),
                'logo' => $this->structureLogo('faculte_id', (int) $faculty->id),
            ]);
        $departmentsRows = DB::table('gnu.departement as d')->when(! $isAdmin, fn ($query) => $query->whereIn('d.id', $departments))
            ->orderBy('d.code_de')->get(['d.id', 'd.code_de', 'd.nom_depart', 'd.faculte_id'])
            ->map(fn (object $department): array => [
                ...((array) $department),
                'logo' => $this->structureLogo('departement_id', (int) $department->id),
            ]);
        $tracks = DB::table('gnu.filiere as f')->when(! $isAdmin, fn ($query) => $query->whereIn('f.departement_id', $departments))
            ->orderBy('f.code_f')->get(['f.id', 'f.code_f', 'f.nom_f', 'f.departement_id']);
        $specialties = DB::table('gnu.specialite as sp')->join('gnu.filiere as f', 'f.id', '=', 'sp.filiere_id')
            ->whereIn('f.departement_id', $departments)->orderBy('f.code_f')->orderBy('sp.code_specialite')
            ->get(['sp.id', 'sp.code_specialite', 'sp.libelle_specialite', 'sp.filiere_id', 'sp.actif', 'f.code_f', 'f.nom_f']);
        $levels = DB::table('gnu.niveau as n')->join('gnu.filiere as f', 'f.id', '=', 'n.filiere_id')
            ->join('gnu.departement as d', 'd.id', '=', 'f.departement_id')
            ->leftJoin('gnu.specialite as sp', 'sp.id', '=', 'n.specialite_id')
            ->whereIn('f.departement_id', $departments)->orderBy('f.code_f')->orderBy('n.code_niv')
            ->get(['n.id', 'n.code_niv', 'n.libelle_niv', 'n.cycle_niv', 'n.filiere_id', 'n.specialite_id', 'f.code_f', 'f.nom_f', 'd.code_de', 'sp.code_specialite', 'sp.libelle_specialite']);

        return response()->json(['data' => [
            'administrateur' => $isAdmin,
            'universites' => $universities,
            'facultes' => $faculties,
            'departements' => $departmentsRows,
            'filieres' => $tracks,
            'specialites' => $specialties,
            'niveaux' => $levels,
        ]]);
    }

    public function uploadStructureLogo(Request $request, string $type, int $id): JsonResponse
    {
        $request->validate(['logo' => ['required', 'image', 'mimes:png,jpg,jpeg,webp', 'max:2048']]);
        $departments = $this->departmentIds($request);
        $isAdmin = $this->isPublicationAdministrator($request);
        $column = match ($type) {
            'universite' => 'universite_id',
            'faculte' => 'faculte_id',
            'departement' => 'departement_id',
            default => abort(404),
        };
        $visible = match ($type) {
            'departement' => $isAdmin || in_array($id, $departments, true),
            'faculte' => $isAdmin || DB::table('gnu.departement')->where('faculte_id', $id)->whereIn('id', $departments)->exists(),
            'universite' => $isAdmin || DB::table('gnu.faculte as fac')->join('gnu.departement as d', 'd.faculte_id', '=', 'fac.id')
                ->where('fac.universite_id', $id)->whereIn('d.id', $departments)->exists(),
        };
        abort_unless($visible, 404);

        $file = $request->file('logo');
        $mime = (string) $file->getMimeType();
        abort_unless(in_array($mime, ['image/png', 'image/jpeg', 'image/webp'], true), 422, 'Format de logo non pris en charge.');
        $path = $file->store('logos-structures/'.$type.'/'.$id, 'local');
        abort_if($path === false, 500, 'Le logo n’a pas pu être enregistré.');

        $existing = DB::table('gnu.logo_structure')->where($column, $id)->first(['id', 'chemin_fichier']);
        DB::transaction(function () use ($request, $column, $id, $mime, $path, $existing): void {
            if ($existing !== null) {
                DB::table('gnu.logo_structure')->where('id', $existing->id)->update([
                    'chemin_fichier' => $path, 'type_mime' => $mime,
                    'updated_by' => $request->user()->id, 'updated_at' => now(),
                ]);
            } else {
                DB::table('gnu.logo_structure')->insert([
                    $column => $id, 'chemin_fichier' => $path, 'type_mime' => $mime,
                    'updated_by' => $request->user()->id, 'created_at' => now(), 'updated_at' => now(),
                ]);
            }
        });
        if ($existing !== null && $existing->chemin_fichier !== $path) {
            Storage::disk('local')->delete($existing->chemin_fichier);
        }

        return response()->json(['message' => 'Logo de la structure enregistré.', 'data' => [
            'type' => $type, 'id' => $id, 'logo' => $this->structureLogo($column, $id),
        ]]);
    }

    private function structureLogo(string $column, int $id): ?array
    {
        $logo = DB::table('gnu.logo_structure')->where($column, $id)->first(['chemin_fichier', 'type_mime']);
        if ($logo === null || ! Storage::disk('local')->exists($logo->chemin_fichier)) {
            return null;
        }

        return ['mime' => $logo->type_mime, 'base64' => base64_encode(Storage::disk('local')->get($logo->chemin_fichier))];
    }

    public function storeSpecialty(Request $request): JsonResponse
    {
        $data = $request->validate([
            'filiere_id' => ['required', 'integer', 'min:1'],
            'code_specialite' => ['required', 'string', 'max:32'],
            'libelle_specialite' => ['required', 'string', 'max:255'],
        ]);
        $track = DB::table('gnu.filiere')->where('id', $data['filiere_id'])->first(['id', 'departement_id']);
        abort_unless($track !== null && in_array((int) $track->departement_id, $this->departmentIds($request), true), 404);
        $id = DB::transaction(function () use ($request, $data): int {
            $this->setAuditContext($request, 'Création d’une spécialité de filière');

            return (int) DB::table('gnu.specialite')->insertGetId($data + ['actif' => true, 'created_at' => now(), 'updated_at' => now()], 'id');
        });

        return response()->json(['id' => $id, 'message' => 'Spécialité créée.'], 201);
    }

    public function updateSpecialty(Request $request, int $specialite): JsonResponse
    {
        $data = $request->validate([
            'filiere_id' => ['required', 'integer', 'min:1'],
            'code_specialite' => ['required', 'string', 'max:32'],
            'libelle_specialite' => ['required', 'string', 'max:255'],
        ]);
        $departments = $this->departmentIds($request);
        $current = DB::table('gnu.specialite as sp')->join('gnu.filiere as f', 'f.id', '=', 'sp.filiere_id')
            ->where('sp.id', $specialite)->first(['sp.filiere_id', 'f.departement_id']);
        abort_unless($current !== null && in_array((int) $current->departement_id, $departments, true), 404);
        $targetTrack = DB::table('gnu.filiere')->where('id', $data['filiere_id'])->first(['id', 'departement_id']);
        abort_unless($targetTrack !== null && in_array((int) $targetTrack->departement_id, $departments, true), 404);
        $hasLevels = DB::table('gnu.niveau')->where('specialite_id', $specialite)->exists();
        abort_if($hasLevels && ((int) $current->filiere_id !== (int) $data['filiere_id']
            || DB::table('gnu.specialite')->where('id', $specialite)->value('code_specialite') !== $data['code_specialite']),
            409, 'Cette spécialité est déjà rattachée à des niveaux. Son code et sa filière sont figés; vous pouvez modifier son intitulé.');

        DB::transaction(function () use ($request, $data, $specialite): void {
            $this->setAuditContext($request, 'Modification d’une spécialité de filière');
            DB::table('gnu.specialite')->where('id', $specialite)->update($data + ['updated_at' => now()]);
        });

        return response()->json(['message' => 'Spécialité mise à jour.']);
    }

    public function storeLevel(Request $request): JsonResponse
    {
        $data = $request->validate([
            'filiere_id' => ['required', 'integer', 'min:1'],
            'specialite_id' => ['present', 'nullable', 'integer', 'min:1'],
            'code_niv' => ['required', 'string', 'max:32'],
            'libelle_niv' => ['required', 'string', 'max:255'],
            'cycle_niv' => ['required', 'in:LICENCE,MASTER,DOCTORAT'],
        ]);
        $track = DB::table('gnu.filiere')->where('id', $data['filiere_id'])->first(['id', 'departement_id']);
        abort_unless($track !== null && in_array((int) $track->departement_id, $this->departmentIds($request), true), 404);
        if (! empty($data['specialite_id'])) {
            abort_unless(DB::table('gnu.specialite')->where('id', $data['specialite_id'])->where('filiere_id', $track->id)->where('actif', true)->exists(), 422, 'La spécialité doit appartenir à la filière sélectionnée et être active.');
        }
        $id = DB::transaction(function () use ($request, $data): int {
            $this->setAuditContext($request, 'Création d’un niveau de formation');

            return (int) DB::table('gnu.niveau')->insertGetId($data + ['specialite_id' => null, 'created_at' => now(), 'updated_at' => now()], 'id');
        });

        return response()->json(['id' => $id, 'message' => 'Niveau créé.'], 201);
    }

    public function updateLevel(Request $request, int $niveau): JsonResponse
    {
        $data = $request->validate([
            'filiere_id' => ['required', 'integer', 'min:1'],
            'specialite_id' => ['present', 'nullable', 'integer', 'min:1'],
            'code_niv' => ['required', 'string', 'max:32'],
            'libelle_niv' => ['required', 'string', 'max:255'],
            'cycle_niv' => ['required', 'in:LICENCE,MASTER,DOCTORAT'],
        ]);
        $departments = $this->departmentIds($request);
        $current = DB::table('gnu.niveau as n')->join('gnu.filiere as f', 'f.id', '=', 'n.filiere_id')
            ->where('n.id', $niveau)->first(['n.filiere_id', 'n.specialite_id', 'n.code_niv', 'n.cycle_niv', 'f.departement_id']);
        abort_unless($current !== null && in_array((int) $current->departement_id, $departments, true), 404);
        $targetTrack = DB::table('gnu.filiere')->where('id', $data['filiere_id'])->first(['id', 'departement_id']);
        abort_unless($targetTrack !== null && in_array((int) $targetTrack->departement_id, $departments, true), 404);
        if ($data['specialite_id'] !== null) {
            abort_unless(DB::table('gnu.specialite')->where('id', $data['specialite_id'])->where('filiere_id', $targetTrack->id)->where('actif', true)->exists(), 422, 'La spécialité doit appartenir à la filière sélectionnée et être active.');
        }
        $identityChanged = (int) $current->filiere_id !== (int) $data['filiere_id']
            || (int) ($current->specialite_id ?? 0) !== (int) ($data['specialite_id'] ?? 0)
            || $current->code_niv !== $data['code_niv']
            || $current->cycle_niv !== $data['cycle_niv'];
        $hasAcademicRecords = DB::table('gnu.classe')->where('niveau_id', $niveau)->exists()
            || DB::table('gnu.ue')->where('niveau_id', $niveau)->exists();
        abort_if($identityChanged && $hasAcademicRecords, 409, 'Ce niveau est déjà utilisé par des classes ou des UE. Son code, son cycle, sa filière et sa spécialité sont figés; seul son libellé peut être modifié.');

        DB::transaction(function () use ($request, $data, $niveau): void {
            $this->setAuditContext($request, 'Modification d’un niveau de formation');
            DB::table('gnu.niveau')->where('id', $niveau)->update($data + ['updated_at' => now()]);
        });

        return response()->json(['message' => 'Niveau mis à jour.']);
    }

    public function generateTrackLevels(Request $request): JsonResponse
    {
        $data = $request->validate([
            'filiere_id' => ['required', 'integer', 'min:1'],
            'cycle_niv' => ['required', 'in:LICENCE,MASTER,DOCTORAT'],
            'specialite_id' => ['nullable', 'integer', 'min:1'],
            'niveau_debut_specialite' => ['nullable', 'string', 'max:8'],
        ]);
        $track = DB::table('gnu.filiere')->where('id', $data['filiere_id'])->first(['id', 'departement_id']);
        abort_unless($track !== null && in_array((int) $track->departement_id, $this->departmentIds($request), true), 404);
        $sequence = match ($data['cycle_niv']) {
            'LICENCE' => [['L1', 'Licence 1'], ['L2', 'Licence 2'], ['L3', 'Licence 3']],
            'MASTER' => [['M1', 'Master 1'], ['M2', 'Master 2']],
            'DOCTORAT' => [['D1', 'Doctorat 1'], ['D2', 'Doctorat 2'], ['D3', 'Doctorat 3']],
        };
        $specialtyId = isset($data['specialite_id']) ? (int) $data['specialite_id'] : null;
        $startCode = $data['niveau_debut_specialite'] ?? null;
        abort_if(($specialtyId === null) !== ($startCode === null), 422, 'Choisissez à la fois une spécialité et le niveau où elle commence.');
        if ($specialtyId !== null) {
            abort_unless(DB::table('gnu.specialite')->where('id', $specialtyId)->where('filiere_id', $track->id)->where('actif', true)->exists(), 422, 'La spécialité doit appartenir à la filière sélectionnée et être active.');
            abort_unless(collect($sequence)->contains(static fn (array $level): bool => $level[0] === $startCode), 422, 'Le niveau de début ne correspond pas au cycle choisi.');
        }
        $created = DB::transaction(function () use ($request, $data, $sequence, $specialtyId, $startCode): int {
            $this->setAuditContext($request, 'Génération des niveaux d’une filière');
            $created = 0;
            $specialty = $specialtyId === null ? null : DB::table('gnu.specialite')->where('id', $specialtyId)->first(['code_specialite', 'libelle_specialite']);
            $specialized = false;
            foreach ($sequence as [$baseCode, $baseLabel]) {
                if ($baseCode === $startCode) {
                    $specialized = true;
                }
                $code = $specialized ? $baseCode.'-'.$specialty->code_specialite : $baseCode;
                $label = $specialized ? $baseLabel.' · '.$specialty->libelle_specialite : $baseLabel;
                $exists = DB::table('gnu.niveau')->where('filiere_id', $data['filiere_id'])->where('code_niv', $code)->exists();
                if ($exists) {
                    continue;
                }
                DB::table('gnu.niveau')->insert([
                    'filiere_id' => $data['filiere_id'],
                    'specialite_id' => $specialized ? $specialtyId : null,
                    'code_niv' => $code,
                    'libelle_niv' => $label,
                    'cycle_niv' => $data['cycle_niv'],
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);
                $created++;
            }

            return $created;
        });

        return response()->json(['nombre_niveaux_crees' => $created, 'message' => "Génération terminée : $created niveau(x) ajouté(s); les niveaux déjà présents ont été conservés."]);
    }

    public function storeUniversity(Request $request): JsonResponse
    {
        $data = $request->validate(['code_univ' => ['required', 'string', 'max:32'], 'nom_univ' => ['required', 'string', 'max:255']]);
        $id = DB::transaction(function () use ($request, $data): int {
            $this->setAuditContext($request, 'Création d’une université');

            return (int) DB::table('gnu.universite')->insertGetId($data + ['created_at' => now(), 'updated_at' => now()], 'id');
        });

        return response()->json(['id' => $id, 'message' => 'Université créée.'], 201);
    }

    public function updateUniversity(Request $request, int $universite): JsonResponse
    {
        $data = $request->validate(['code_univ' => ['required', 'string', 'max:32'], 'nom_univ' => ['required', 'string', 'max:255']]);
        $departments = $this->departmentIds($request);
        $visible = $this->isPublicationAdministrator($request) || DB::table('gnu.departement as d')
            ->join('gnu.faculte as fac', 'fac.id', '=', 'd.faculte_id')->where('fac.universite_id', $universite)->whereIn('d.id', $departments)->exists();
        abort_unless($visible, 404);
        DB::transaction(function () use ($request, $data, $universite): void {
            $this->setAuditContext($request, 'Modification de l’université');
            DB::table('gnu.universite')->where('id', $universite)->update($data + ['updated_at' => now()]);
        });

        return response()->json(['message' => 'Université mise à jour.']);
    }

    public function storeFaculty(Request $request): JsonResponse
    {
        $data = $request->validate(['universite_id' => ['required', 'integer', 'min:1'], 'code_fac' => ['required', 'string', 'max:32'], 'nom_fac' => ['required', 'string', 'max:255']]);
        abort_unless(DB::table('gnu.universite')->where('id', $data['universite_id'])->exists(), 422, 'Université introuvable.');
        $id = DB::transaction(function () use ($request, $data): int {
            $this->setAuditContext($request, 'Création d’une faculté');

            return (int) DB::table('gnu.faculte')->insertGetId($data + ['created_at' => now(), 'updated_at' => now()], 'id');
        });

        return response()->json(['id' => $id, 'message' => 'Faculté créée.'], 201);
    }

    public function updateFaculty(Request $request, int $faculte): JsonResponse
    {
        $data = $request->validate(['universite_id' => ['required', 'integer', 'min:1'], 'code_fac' => ['required', 'string', 'max:32'], 'nom_fac' => ['required', 'string', 'max:255']]);
        $departments = $this->departmentIds($request);
        $visible = $this->isPublicationAdministrator($request) || DB::table('gnu.departement')->where('faculte_id', $faculte)->whereIn('id', $departments)->exists();
        abort_unless($visible && DB::table('gnu.universite')->where('id', $data['universite_id'])->exists(), 404);
        $faculty = DB::table('gnu.faculte')->where('id', $faculte)->first(['universite_id']);
        abort_if($faculty !== null && (int) $faculty->universite_id !== (int) $data['universite_id']
            && DB::table('gnu.departement')->where('faculte_id', $faculte)->exists(), 409, 'La faculté possède des départements; son université de rattachement est figée.');
        if (! $this->isPublicationAdministrator($request)) {
            abort_unless(DB::table('gnu.departement as d')->join('gnu.faculte as fac', 'fac.id', '=', 'd.faculte_id')
                ->whereIn('d.id', $departments)->where('fac.universite_id', $data['universite_id'])->exists(), 404);
        }
        DB::transaction(function () use ($request, $data, $faculte): void {
            $this->setAuditContext($request, 'Modification de la faculté');
            DB::table('gnu.faculte')->where('id', $faculte)->update($data + ['updated_at' => now()]);
        });

        return response()->json(['message' => 'Faculté mise à jour.']);
    }

    public function storeDepartment(Request $request): JsonResponse
    {
        $data = $request->validate(['faculte_id' => ['required', 'integer', 'min:1'], 'code_de' => ['required', 'string', 'max:32'], 'nom_depart' => ['required', 'string', 'max:255']]);
        abort_unless(DB::table('gnu.faculte')->where('id', $data['faculte_id'])->exists(), 404, 'Faculté introuvable.');
        $id = DB::transaction(function () use ($request, $data): int {
            $this->setAuditContext($request, 'Création d’un département');
            $departmentId = (int) DB::table('gnu.departement')->insertGetId($data + ['created_at' => now(), 'updated_at' => now()], 'id');
            if (! $this->isPublicationAdministrator($request)) {
                DB::table('gnu.agent_departement')->insertOrIgnore(['agent_id' => $request->user()->id, 'departement_id' => $departmentId, 'created_at' => now()]);
            }

            return $departmentId;
        });

        return response()->json(['id' => $id, 'message' => 'Département créé.'], 201);
    }

    public function updateDepartment(Request $request, int $departement): JsonResponse
    {
        $data = $request->validate(['faculte_id' => ['required', 'integer', 'min:1'], 'code_de' => ['required', 'string', 'max:32'], 'nom_depart' => ['required', 'string', 'max:255']]);
        $departments = $this->departmentIds($request);
        $isAdmin = $this->isPublicationAdministrator($request);
        abort_unless(($isAdmin || in_array($departement, $departments, true)) && DB::table('gnu.faculte')->where('id', $data['faculte_id'])->exists(), 404);
        $current = DB::table('gnu.departement')->where('id', $departement)->first(['faculte_id']);
        abort_if($current !== null && (int) $current->faculte_id !== (int) $data['faculte_id']
            && DB::table('gnu.filiere')->where('departement_id', $departement)->exists(), 409, 'Le département contient des filières; sa faculté de rattachement est figée.');
        if (! $isAdmin) {
            abort_unless(DB::table('gnu.departement')->whereIn('id', $departments)->where('faculte_id', $data['faculte_id'])->exists(), 404);
        }
        DB::transaction(function () use ($request, $data, $departement): void {
            $this->setAuditContext($request, 'Modification d’un département');
            DB::table('gnu.departement')->where('id', $departement)->update($data + ['updated_at' => now()]);
        });

        return response()->json(['message' => 'Département mis à jour.']);
    }

    public function storeTrack(Request $request): JsonResponse
    {
        $data = $request->validate(['departement_id' => ['required', 'integer', 'min:1'], 'code_f' => ['required', 'string', 'max:32'], 'nom_f' => ['required', 'string', 'max:255']]);
        $departments = $this->departmentIds($request);
        abort_unless($this->isPublicationAdministrator($request) || in_array((int) $data['departement_id'], $departments, true), 404);
        $id = DB::transaction(function () use ($request, $data): int {
            $this->setAuditContext($request, 'Création d’une filière');

            return (int) DB::table('gnu.filiere')->insertGetId($data + ['created_at' => now(), 'updated_at' => now()], 'id');
        });

        return response()->json(['id' => $id, 'message' => 'Filière créée.'], 201);
    }

    public function updateTrack(Request $request, int $filiere): JsonResponse
    {
        $data = $request->validate(['departement_id' => ['required', 'integer', 'min:1'], 'code_f' => ['required', 'string', 'max:32'], 'nom_f' => ['required', 'string', 'max:255']]);
        $departments = $this->departmentIds($request);
        $isAdmin = $this->isPublicationAdministrator($request);
        $existing = DB::table('gnu.filiere')->where('id', $filiere)->first(['departement_id']);
        abort_unless($existing !== null && ($isAdmin || in_array((int) $existing->departement_id, $departments, true))
            && ($isAdmin || in_array((int) $data['departement_id'], $departments, true)), 404);
        abort_if((int) $existing->departement_id !== (int) $data['departement_id']
            && DB::table('gnu.niveau')->where('filiere_id', $filiere)->exists(), 409, 'La filière contient des niveaux; son département de rattachement est figé.');
        DB::transaction(function () use ($request, $data, $filiere): void {
            $this->setAuditContext($request, 'Modification d’une filière');
            DB::table('gnu.filiere')->where('id', $filiere)->update($data + ['updated_at' => now()]);
        });

        return response()->json(['message' => 'Filière mise à jour.']);
    }

    public function catalog(Request $request): JsonResponse
    {
        $departments = $this->departmentIds($request);
        $units = DB::table('gnu.ue as u')
            ->join('gnu.niveau as n', 'n.id', '=', 'u.niveau_id')
            ->join('gnu.filiere as f', 'f.id', '=', 'n.filiere_id')
            ->join('gnu.departement as d', 'd.id', '=', 'f.departement_id')
            ->join('gnu.faculte as fac', 'fac.id', '=', 'd.faculte_id')
            ->join('gnu.universite as un', 'un.id', '=', 'fac.universite_id')
            ->leftJoin('gnu.specialite as sp', 'sp.id', '=', 'n.specialite_id')
            ->leftJoin('gnu.profil_evaluation_ue as profil', 'profil.ue_id', '=', 'u.id')
            ->leftJoin(DB::raw("(SELECT DISTINCT ON (ue_id) ue_id, code_profil, created_at FROM gnu.proposition_profil_evaluation WHERE statut = 'EN_ATTENTE' ORDER BY ue_id, created_at DESC) as proposition"), 'proposition.ue_id', '=', 'u.id')
            ->whereIn('f.departement_id', $departments)->orderBy('u.code_ue')
            ->get([
                'u.id', 'u.code_ue', 'u.intitule_ue', 'u.niveau_id', 'n.libelle_niv', 'f.code_f', 'f.nom_f',
                'd.nom_depart', 'fac.code_fac', 'fac.nom_fac', 'un.nom_univ', 'sp.libelle_specialite',
                'u.version_programme', 'u.numero_semestre', 'u.categorie_ue', 'u.credit_ue', 'u.statut_catalogue',
                'profil.code_profil as profil_evaluation',
                'proposition.code_profil as profil_propose',
            ]);
        $elements = DB::table('gnu.matiere as m')
            ->join('gnu.ue as u', 'u.id', '=', 'm.ue_id')
            ->join('gnu.niveau as n', 'n.id', '=', 'u.niveau_id')
            ->join('gnu.filiere as f', 'f.id', '=', 'n.filiere_id')
            ->join('gnu.departement as d', 'd.id', '=', 'f.departement_id')
            ->join('gnu.faculte as fac', 'fac.id', '=', 'd.faculte_id')
            ->join('gnu.universite as un', 'un.id', '=', 'fac.universite_id')
            ->whereIn('f.departement_id', $departments)->orderBy('u.code_ue')->orderBy('m.rang_ec')
            ->get([
                'm.id', 'm.ue_id', 'm.code_m', 'm.intitule_matiere', 'm.rang_ec', 'm.credit_matiere',
                'u.niveau_id', 'u.version_programme', 'u.statut_catalogue', 'f.code_f', 'd.nom_depart',
                'fac.code_fac', 'fac.nom_fac', 'un.nom_univ',
            ]);

        return response()->json(['data' => ['ues' => $units, 'elements_constitutifs' => $elements]]);
    }

    public function storeClass(Request $request): JsonResponse
    {
        $data = $request->validate([
            'code_classe' => ['required', 'string', 'max:64'],
            'niveau_id' => ['required', 'integer', 'min:1'],
            'annee_id' => ['required', 'integer', 'min:1'],
        ]);
        $departments = $this->departmentIds($request);
        abort_unless($this->scope->hasLevel($departments, (int) $data['niveau_id']), 404);
        abort_unless(DB::table('gnu.annee_academique')->where('id', $data['annee_id'])->exists(), 422, 'Année académique inconnue.');

        // A class belongs to an academic year. Its technical catalogue link
        // always points to the latest active syllabus for its level.
        $activeVersion = DB::table('gnu.ue')->where('niveau_id', $data['niveau_id'])
            ->where('statut_catalogue', 'ACTIF')->select('version_programme')
            ->groupBy('version_programme')->orderByRaw('COUNT(*) DESC')->orderByDesc('version_programme')->value('version_programme');
        $version = $activeVersion;
        abort_unless($version !== null, 422, 'Aucun programme actif n’est configuré pour ce niveau.');

        $id = DB::transaction(function () use ($request, $data, $version): int {
            $this->setAuditContext($request, 'Création d’une classe dans le périmètre départemental');

            return (int) DB::table('gnu.classe')->insertGetId([
                'code_classe' => trim($data['code_classe']),
                'niveau_id' => $data['niveau_id'],
                'annee_id' => $data['annee_id'],
                'version_programme' => (int) $version,
                'created_at' => now(),
                'updated_at' => now(),
            ], 'id');
        });

        return response()->json([
            'id' => $id,
            'message' => 'Classe créée pour l’année académique sélectionnée avec le catalogue du syllabus applicable au niveau.',
        ], 201);
    }

    public function storeUnit(Request $request): JsonResponse
    {
        $data = $request->validate([
            'code_ue' => ['required', 'string', 'max:32'],
            'intitule_ue' => ['required', 'string', 'max:255'],
            'niveau_id' => ['required', 'integer', 'min:1'],
            'version_programme' => ['sometimes', 'integer', 'min:1'],
            'numero_semestre' => ['required', 'integer', 'in:1,2'],
            'categorie_ue' => ['required', 'in:FONDAMENTALE,OPTIONNELLE'],
            'credit_ue' => ['required', 'numeric', 'gt:0', 'max:60'],
        ]);
        $departments = $this->departmentIds($request);
        abort_unless($this->scope->hasLevel($departments, (int) $data['niveau_id']), 404);

        $data['version_programme'] = DB::table('gnu.ue')->where('niveau_id', $data['niveau_id'])
            ->where('statut_catalogue', 'ACTIF')->select('version_programme')
            ->groupBy('version_programme')->orderByRaw('COUNT(*) DESC')->orderByDesc('version_programme')->value('version_programme') ?? 1;

        $id = DB::transaction(function () use ($request, $data): int {
            $this->setAuditContext($request, 'Création d’une UE en brouillon');

            return (int) DB::table('gnu.ue')->insertGetId([
                ...$data,
                'statut_catalogue' => 'BROUILLON',
                'created_at' => now(),
                'updated_at' => now(),
            ], 'id');
        });

        return response()->json(['id' => $id, 'message' => 'UE créée en brouillon.'], 201);
    }

    public function storeElement(Request $request, int $ue): JsonResponse
    {
        $data = $request->validate([
            'code_m' => ['required', 'string', 'max:32'],
            'intitule_matiere' => ['required', 'string', 'max:255'],
            'rang_ec' => ['required', 'integer', 'in:1,2'],
            'credit_matiere' => ['required', 'numeric', 'gt:0', 'max:60'],
        ]);
        $departments = $this->departmentIds($request);
        abort_unless($this->scope->hasUnit($departments, $ue), 404);
        abort_unless(DB::table('gnu.ue')->where('id', $ue)->where('statut_catalogue', 'BROUILLON')->exists(), 409, 'Les EC ne peuvent être modifiés que dans une UE brouillon.');

        $id = DB::transaction(function () use ($request, $data, $ue): int {
            $this->setAuditContext($request, 'Ajout d’un élément constitutif');

            return (int) DB::table('gnu.matiere')->insertGetId([
                ...$data,
                'ue_id' => $ue,
                'created_at' => now(),
                'updated_at' => now(),
            ], 'id');
        });

        return response()->json(['id' => $id, 'message' => 'Élément constitutif ajouté.'], 201);
    }

    public function setUnitStatus(Request $request, int $ue): JsonResponse
    {
        $data = $request->validate(['statut_catalogue' => ['required', 'in:ACTIF,ARCHIVE']]);
        $departments = $this->departmentIds($request);
        abort_unless($this->scope->hasUnit($departments, $ue), 404);
        $unit = DB::table('gnu.ue as ue')
            ->join('gnu.niveau as n', 'n.id', '=', 'ue.niveau_id')
            ->join('gnu.filiere as f', 'f.id', '=', 'n.filiere_id')
            ->where('ue.id', $ue)
            ->first(['ue.*', 'n.code_niv', 'f.code_f']);
        abort_unless($unit !== null && $unit->statut_catalogue === 'BROUILLON' && $data['statut_catalogue'] === 'ACTIF' || $unit !== null && $unit->statut_catalogue === 'ACTIF' && $data['statut_catalogue'] === 'ARCHIVE', 409, 'Transition de catalogue non autorisée.');
        if ($data['statut_catalogue'] === 'ACTIF') {
            $count = DB::table('gnu.matiere')->where('ue_id', $ue)->count();
            $isThesisUnit = $unit->code_ue === 'INF500'
                && $unit->code_niv === 'M2'
                && $unit->code_f === 'INF'
                && (int) $unit->numero_semestre === 2
                && (float) $unit->credit_ue === 60.0;
            abort_unless($count >= 1 && $count <= 2 || $isThesisUnit && $count === 0, 422, 'Une UE active doit comporter un ou deux EC, sauf INF500 qui est une UE de mémoire sans EC dans le syllabus.');
        }

        DB::transaction(function () use ($request, $data, $ue): void {
            $this->setAuditContext($request, 'Changement du statut d’une UE');
            DB::table('gnu.ue')->where('id', $ue)->update(['statut_catalogue' => $data['statut_catalogue'], 'updated_at' => now()]);
        });

        return response()->json(['message' => 'Statut du catalogue mis à jour.']);
    }

    public function setUnitEvaluationProfile(Request $request, int $ue): JsonResponse
    {
        $data = $request->validate(['code_profil' => ['required', 'in:CC_SN,CC_TP_SN,CC_TPE_SN']]);
        $departments = $this->departmentIds($request);
        abort_unless($this->scope->hasUnit($departments, $ue), 404);

        DB::transaction(function () use ($request, $data, $ue): void {
            $this->setAuditContext($request, 'Définition du profil officiel d’évaluation de l’UE');
            $unit = DB::table('gnu.ue')->where('id', $ue)->lockForUpdate()->first();
            abort_unless($unit !== null, 404);
            $existing = DB::table('gnu.profil_evaluation_ue')->where('ue_id', $ue)->value('code_profil');
            $hasGrades = DB::table('gnu.affectation as a')->join('gnu.matiere as m', 'm.id', '=', 'a.matiere_id')
                ->join('gnu.evaluation as ev', 'ev.affectation_id', '=', 'a.id')->join('gnu.note as no', 'no.evaluation_id', '=', 'ev.id')
                ->where('m.ue_id', $ue)->exists();
            abort_if($hasGrades && $existing !== $data['code_profil'], 409, 'Le profil ne peut pas être défini ou changé après la saisie de notes dans cette UE.');
            DB::table('gnu.profil_evaluation_ue')->updateOrInsert(
                ['ue_id' => $ue],
                ['code_profil' => $data['code_profil'], 'configure_par' => $request->user()->id, 'updated_at' => now(), 'created_at' => now()],
            );
            $profile = $data['code_profil'];
            $weights = match ($profile) {
                'CC_SN' => ['CC' => 30.0, 'SN' => 70.0],
                'CC_TP_SN' => ['CC' => 20.0, 'TP' => 30.0, 'SN' => 50.0],
                'CC_TPE_SN' => ['CC' => 20.0, 'TPE' => 20.0, 'SN' => 60.0],
            };
            $assignments = DB::table('gnu.affectation as a')
                ->join('gnu.matiere as m', 'm.id', '=', 'a.matiere_id')
                ->where('m.ue_id', $ue)
                ->where(function ($query): void {
                    $query->where('a.actif', true)->orWhereExists(function ($proposal): void {
                        $proposal->selectRaw('1')->from('gnu.proposition_affectation_enseignant as p')
                            ->whereColumn('p.affectation_id', 'a.id')->where('p.statut', 'EN_ATTENTE');
                    });
                })
                ->get(['a.id', 'a.classe_id', 'a.enseignant_id']);
            foreach ($assignments as $assignment) {
                DB::table('gnu.affectation')->where('id', $assignment->id)->lockForUpdate()->first();
                $activePlan = DB::table('gnu.plan_evaluation')->where('affectation_id', $assignment->id)
                    ->where('portee', 'CLASSE')->where('statut_plan', 'ACTIF')->orderByDesc('version_plan')->first();
                $current = $activePlan === null ? [] : DB::table('gnu.ligne_plan as lp')
                    ->join('gnu.evaluation as ev', 'ev.id', '=', 'lp.evaluation_id')
                    ->where('lp.plan_id', $activePlan->id)->where('lp.retenue', true)
                    ->get(['ev.type_eval', 'lp.poids_evaluation'])->groupBy('type_eval')
                    ->map(fn ($rows): float => (float) $rows->sum('poids_evaluation'))->all();
                $sameProfile = count($current) === count($weights);
                foreach ($weights as $type => $weight) {
                    if (abs((float) ($current[$type] ?? 0) - $weight) > 0.0001) {
                        $sameProfile = false;
                        break;
                    }
                }
                if ($sameProfile) {
                    continue;
                }
                $hasNonProvisionalGrades = $activePlan !== null && DB::table('gnu.ligne_plan as lp')
                    ->join('gnu.note as n', 'n.evaluation_id', '=', 'lp.evaluation_id')
                    ->where('lp.plan_id', $activePlan->id)
                    ->whereNotExists(function ($query): void {
                        $query->selectRaw('1')->from('gnu.proposition_profil_evaluation as pp')
                            ->whereColumn('pp.affectation_id', 'lp.affectation_id')
                            ->where('pp.statut', 'EN_ATTENTE');
                    })->exists();
                abort_if($hasNonProvisionalGrades, 409, 'Un profil de notation différent ne peut être appliqué après la saisie des notes.');
                if ($activePlan !== null) {
                    DB::table('gnu.plan_evaluation')->where('id', $activePlan->id)
                        ->update(['statut_plan' => 'ARCHIVE', 'updated_at' => now()]);
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
                foreach ($weights as $type => $weight) {
                    $evaluationId = (int) DB::table('gnu.evaluation')->insertGetId([
                        'affectation_id' => $assignment->id,
                        'type_eval' => $type,
                        'date_evaluation' => now()->toDateString(),
                        'mode_evaluation' => 'NORMALE',
                        'statut_evaluation' => 'PROGRAMMEE',
                        'evaluation_origine_id' => null,
                        'version_calendrier' => 'V1',
                        'created_at' => now(),
                        'updated_at' => now(),
                    ], 'id');
                    DB::table('gnu.ligne_plan')->insert([
                        'plan_id' => $planId,
                        'evaluation_id' => $evaluationId,
                        'retenue' => true,
                        'poids_evaluation' => $weight,
                        'created_at' => now(),
                        'updated_at' => now(),
                    ]);
                }
                DB::table('gnu.plan_evaluation')->where('id', $planId)
                    ->update(['statut_plan' => 'ACTIF', 'updated_at' => now()]);
            }
            DB::table('gnu.proposition_profil_evaluation')->where('ue_id', $ue)->where('statut', 'EN_ATTENTE')->update([
                'statut' => 'REJETEE', 'updated_at' => now(),
            ]);
            DB::table('gnu.proposition_profil_evaluation')->where('ue_id', $ue)->where('code_profil', $data['code_profil'])->where('statut', 'REJETEE')->update([
                'statut' => 'APPROUVEE', 'updated_at' => now(),
            ]);
        });

        return response()->json(['message' => 'Profil officiel d’évaluation enregistré.']);
    }

    public function accounts(Request $request): JsonResponse
    {
        $departments = $this->departmentIds($request);
        $ids = $this->scope->visibleUserIds($departments);
        $rows = DB::table('gnu.utilisateur as u')
            ->leftJoin('gnu.etudiant as e', 'e.utilisateur_id', '=', 'u.id')
            ->leftJoin('gnu.enseignant as t', 't.utilisateur_id', '=', 'u.id')
            ->whereIn('u.id', $ids)
            ->orderBy('u.role')->orderBy('u.nom')
            ->get(['u.id', 'u.login', 'u.role', 'u.actif', 'u.nom', 'u.prenom', 'u.courriel', 'e.id as etudiant_id', 'e.matricule', 't.id as enseignant_id', 't.eid', 't.fonction_enseignant']);
        $studentIds = $rows->pluck('etudiant_id')->filter()->unique()->values()->all();
        // Un utilisateur peut avoir un profil enseignant en plus de son rôle Agent.
        $teacherIds = $rows->pluck('enseignant_id')->filter()->unique()->values()->all();
        $studentClasses = DB::table('gnu.inscription_classe as ic')
            ->join('gnu.classe as c', 'c.id', '=', 'ic.classe_id')
            ->join('gnu.niveau as n', 'n.id', '=', 'c.niveau_id')
            ->join('gnu.filiere as f', 'f.id', '=', 'n.filiere_id')
            ->join('gnu.annee_academique as an', 'an.id', '=', 'c.annee_id')
            ->whereIn('ic.etudiant_id', $studentIds)->whereIn('f.departement_id', $departments)
            ->when($request->filled('annee_id'), fn ($query) => $query->where('c.annee_id', $request->integer('annee_id')))
            ->orderByDesc('an.date_debut')->orderBy('c.code_classe')
            ->get(['ic.etudiant_id', 'c.id as classe_id', 'c.code_classe', 'an.libelle as annee_academique'])
            ->groupBy('etudiant_id');
        $teacherAssignments = DB::table('gnu.affectation as a')
            ->join('gnu.classe as c', 'c.id', '=', 'a.classe_id')
            ->join('gnu.niveau as n', 'n.id', '=', 'c.niveau_id')
            ->join('gnu.filiere as f', 'f.id', '=', 'n.filiere_id')
            ->join('gnu.departement as d', 'd.id', '=', 'f.departement_id')
            ->join('gnu.faculte as fac', 'fac.id', '=', 'd.faculte_id')
            ->join('gnu.universite as un', 'un.id', '=', 'fac.universite_id')
            ->join('gnu.matiere as m', 'm.id', '=', 'a.matiere_id')
            ->join('gnu.ue as ue', 'ue.id', '=', 'm.ue_id')
            ->join('gnu.annee_academique as an', 'an.id', '=', 'c.annee_id')
            ->whereIn('a.enseignant_id', $teacherIds)
            ->when($request->filled('annee_id'), fn ($query) => $query->where('c.annee_id', $request->integer('annee_id')))
            ->orderBy('d.nom_depart')->orderByDesc('an.date_debut')->orderBy('c.code_classe')->orderBy('ue.code_ue')->orderBy('m.rang_ec')
            ->get(['a.enseignant_id', 'a.actif', 'fac.code_fac', 'd.nom_depart', 'c.code_classe', 'an.libelle as annee_academique', 'ue.code_ue', 'm.code_m'])
            ->groupBy('enseignant_id');
        $rows = $rows->map(function (object $row) use ($ids, $studentClasses, $teacherAssignments): object {
            $row->classes = $row->etudiant_id !== null
                ? ($studentClasses->get($row->etudiant_id, collect())->map(static fn (object $class): string => $class->code_classe.' · '.$class->annee_academique)->unique()->values()->all())
                : ($teacherAssignments->get($row->enseignant_id, collect())->map(static fn (object $class): string => $class->code_classe.' · '.$class->annee_academique)->unique()->values()->all());
            $row->classes_detail = $row->etudiant_id !== null
                ? $studentClasses->get($row->etudiant_id, collect())->map(static fn (object $class): array => [
                    'classe_id' => (int) $class->classe_id,
                    'code_classe' => $class->code_classe,
                    'annee_academique' => $class->annee_academique,
                ])->unique('classe_id')->values()->all()
                : [];
            $row->enseignements = $teacherAssignments->get($row->enseignant_id, collect())
                ->map(static fn (object $course): string => $course->code_fac.' / '.$course->nom_depart.' · '.$course->code_classe.' · '.$course->code_ue.'/'.$course->code_m.($course->actif ? '' : ' (inactive)'))
                ->unique()->values()->all();
            $row->gestionnable = in_array((int) $row->id, $ids, true);

            return $row;
        });

        return response()->json(['data' => $rows]);
    }

    public function updateAccount(Request $request, int $utilisateur): JsonResponse
    {
        $data = $this->normalizeOptionalMotif($request->validate([
            'nom' => ['required', 'string', 'max:120'],
            'prenom' => ['required', 'string', 'max:120'],
            'courriel' => ['nullable', 'email', 'max:255'],
            'motif' => ['nullable', 'string', 'min:8', 'max:500'],
        ]));
        $ids = $this->scope->visibleUserIds($this->departmentIds($request));
        $account = DB::table('gnu.utilisateur')->where('id', $utilisateur)->whereIn('id', $ids)
            ->whereIn('role', ['ETUDIANT', 'ENSEIGNANT'])->first(['id']);
        abort_unless($account !== null, 404);

        DB::transaction(function () use ($request, $data, $utilisateur): void {
            $this->setAuditContext($request, $data['motif']);
            DB::table('gnu.utilisateur')->where('id', $utilisateur)->update([
                'nom' => trim($data['nom']),
                'prenom' => trim($data['prenom']),
                'courriel' => $data['courriel'] === null ? null : trim($data['courriel']),
                'updated_at' => now(),
            ]);
        });

        return response()->json(['message' => 'Profil mis à jour.']);
    }

    public function setAccountStatus(Request $request, int $utilisateur): JsonResponse
    {
        $data = $this->normalizeOptionalMotif($request->validate([
            'actif' => ['required', 'boolean'],
            'motif' => ['nullable', 'string', 'min:8', 'max:500'],
        ]));
        abort_if((int) $request->user()->id === $utilisateur, 422, 'Vous ne pouvez pas suspendre votre propre compte.');
        $ids = $this->scope->visibleUserIds($this->departmentIds($request));
        $account = DB::table('gnu.utilisateur')->where('id', $utilisateur)->whereIn('id', $ids)->first();
        abort_unless($account !== null && in_array($account->role, ['ETUDIANT', 'ENSEIGNANT'], true), 404);

        DB::transaction(function () use ($request, $data, $utilisateur): void {
            $this->setAuditContext($request, $data['motif']);
            DB::table('gnu.utilisateur')->where('id', $utilisateur)->update(['actif' => $data['actif'], 'updated_at' => now()]);
            if (! $data['actif']) {
                DB::table('gnu_auth.personal_access_tokens')->where('tokenable_id', $utilisateur)->delete();
            }
        });

        return response()->json(['message' => $data['actif'] ? 'Compte réactivé.' : 'Compte suspendu et sessions révoquées.']);
    }

    public function assignmentProposals(Request $request): JsonResponse
    {
        $departments = $this->departmentIds($request);
        $rows = DB::table('gnu.proposition_affectation_enseignant as p')
            ->join('gnu.affectation as a', 'a.id', '=', 'p.affectation_id')
            ->join('gnu.enseignant as e', 'e.id', '=', 'a.enseignant_id')
            ->join('gnu.utilisateur as enseignant', 'enseignant.id', '=', 'e.utilisateur_id')
            ->join('gnu.classe as c', 'c.id', '=', 'a.classe_id')
            ->join('gnu.niveau as n', 'n.id', '=', 'c.niveau_id')
            ->join('gnu.filiere as f', 'f.id', '=', 'n.filiere_id')
            ->join('gnu.annee_academique as an', 'an.id', '=', 'c.annee_id')
            ->join('gnu.matiere as m', 'm.id', '=', 'a.matiere_id')
            ->join('gnu.ue as u', 'u.id', '=', 'm.ue_id')
            ->leftJoin('gnu.utilisateur as decideur', 'decideur.id', '=', 'p.decidee_par')
            ->whereIn('f.departement_id', $departments)
            ->where('p.statut', 'EN_ATTENTE')
            ->orderBy('p.soumise_le')
            ->get([
                'p.id', 'p.affectation_id', 'p.statut', 'p.motif_enseignant', 'p.soumise_le',
                'enseignant.id as utilisateur_enseignant_id', 'enseignant.nom as nom_enseignant', 'enseignant.prenom as prenom_enseignant', 'e.eid',
                'c.id as classe_id', 'c.code_classe', 'n.libelle_niv', 'an.libelle as annee_academique',
                'u.id as ue_id', 'u.code_ue', 'u.intitule_ue', 'u.numero_semestre', 'm.id as matiere_id', 'm.code_m', 'm.intitule_matiere',
                'decideur.nom as nom_decideur', 'decideur.prenom as prenom_decideur', 'p.motif_decision',
            ]);

        return response()->json(['data' => $rows->map(fn (object $row): array => [
            ...((array) $row),
            'id' => (int) $row->id,
            'affectation_id' => (int) $row->affectation_id,
            'classe_id' => (int) $row->classe_id,
            'ue_id' => (int) $row->ue_id,
            'matiere_id' => (int) $row->matiere_id,
            'numero_semestre' => (int) $row->numero_semestre,
        ])]);
    }

    public function decideAssignmentProposal(Request $request, int $proposition): JsonResponse
    {
        $data = $this->normalizeOptionalMotif($request->validate([
            'decision' => ['required', 'in:APPROUVER,REJETER'],
            'motif' => ['nullable', 'string', 'min:8', 'max:1000'],
        ]));
        $departments = $this->departmentIds($request);
        $proposal = DB::table('gnu.proposition_affectation_enseignant as p')
            ->join('gnu.affectation as a', 'a.id', '=', 'p.affectation_id')
            ->where('p.id', $proposition)->first([
                'p.id', 'p.affectation_id', 'p.statut', 'a.classe_id', 'a.matiere_id', 'a.enseignant_id',
            ]);
        abort_unless($proposal !== null && $this->scope->hasClass($departments, (int) $proposal->classe_id), 404);
        abort_unless($proposal->statut === 'EN_ATTENTE', 409, 'Cette demande a déjà été traitée.');
        if ($data['decision'] === 'APPROUVER') {
            abort_if(DB::table('gnu.affectation')->where('classe_id', $proposal->classe_id)
                ->where('matiere_id', $proposal->matiere_id)->where('actif', true)->exists(), 409,
                'Cette matière a déjà été attribuée dans la classe.');
        }

        DB::transaction(function () use ($request, $data, $proposal, $proposition): void {
            DB::table('gnu.classe')->where('id', $proposal->classe_id)->lockForUpdate()->first();
            DB::table('gnu.proposition_affectation_enseignant')->where('id', $proposition)->lockForUpdate()->first();
            $locked = DB::table('gnu.proposition_affectation_enseignant')->where('id', $proposition)->first();
            abort_unless($locked?->statut === 'EN_ATTENTE', 409, 'La demande a déjà été traitée. Actualisez la liste.');
            $approved = $data['decision'] === 'APPROUVER';
            if ($approved) {
                abort_if(DB::table('gnu.affectation')->where('classe_id', $proposal->classe_id)
                    ->where('matiere_id', $proposal->matiere_id)->where('actif', true)
                    ->where('id', '<>', $proposal->affectation_id)->exists(), 409,
                    'Cette matière vient d’être attribuée à un autre enseignant.');
            }
            $this->setAuditContext($request, $data['motif']);
            DB::table('gnu.proposition_affectation_enseignant')->where('id', $proposition)->update([
                'statut' => $approved ? 'APPROUVEE' : 'REJETEE',
                'decidee_par' => $request->user()->id,
                'motif_decision' => $data['motif'],
                'decidee_le' => now(),
                'updated_at' => now(),
            ]);
            DB::table('gnu.affectation')->where('id', $proposal->affectation_id)->update([
                'actif' => $approved,
                'updated_at' => now(),
            ]);
            $teacherUserId = DB::table('gnu.enseignant')->where('id', $proposal->enseignant_id)->value('utilisateur_id');
            if ($teacherUserId !== null) {
                $course = DB::table('gnu.matiere as m')->join('gnu.ue as ue', 'ue.id', '=', 'm.ue_id')
                    ->join('gnu.classe as c', fn ($join) => $join->where('c.id', $proposal->classe_id))
                    ->where('m.id', $proposal->matiere_id)->first(['m.code_m', 'ue.code_ue', 'c.code_classe']);
                $decision = $approved ? 'approuvée' : 'refusée';
                DB::table('gnu.notification')->insertOrIgnore([
                    'destinataire_id' => $teacherUserId,
                    'type_notification' => 'AFFECTATION_DECIDEE',
                    'cle_evenement' => 'AFFECTATION|'.$proposition.'|'.($approved ? 'APPROUVEE' : 'REJETEE'),
                    'contenu' => json_encode([
                        'titre' => 'Validation de votre choix d’enseignement',
                        'message' => "Votre choix d’enseigner {$course->code_ue} · {$course->code_m} ({$course->code_classe}) a été {$decision}."
                            .($data['motif'] ? ' Motif : '.$data['motif'] : ''),
                        'proposition_id' => $proposition,
                        'statut' => $approved ? 'APPROUVEE' : 'REJETEE',
                    ], JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE),
                    'date_envoi' => now(),
                    'statut_envoi' => 'ENVOYEE',
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);
            }
        });

        return response()->json(['message' => $data['decision'] === 'APPROUVER'
            ? 'Affectation approuvée. Le carnet provisoire est maintenant actif.'
            : 'Choix refusé. Les brouillons sont conservés dans l’historique.']);
    }

    public function assignments(Request $request): JsonResponse
    {
        $departments = $this->departmentIds($request);
        $rows = DB::table('gnu.affectation as a')->join('gnu.enseignant as e', 'e.id', '=', 'a.enseignant_id')
            ->join('gnu.utilisateur as u', 'u.id', '=', 'e.utilisateur_id')
            ->join('gnu.matiere as m', 'm.id', '=', 'a.matiere_id')->join('gnu.ue as ue', 'ue.id', '=', 'm.ue_id')
            ->join('gnu.classe as c', 'c.id', '=', 'a.classe_id')->join('gnu.niveau as n', 'n.id', '=', 'c.niveau_id')
            ->join('gnu.filiere as f', 'f.id', '=', 'n.filiere_id')
            ->join('gnu.departement as d', 'd.id', '=', 'f.departement_id')
            ->join('gnu.faculte as fac', 'fac.id', '=', 'd.faculte_id')
            ->join('gnu.universite as un', 'un.id', '=', 'fac.universite_id')
            ->join('gnu.annee_academique as an', 'an.id', '=', 'c.annee_id')
            ->leftJoin('gnu.specialite as sp', 'sp.id', '=', 'n.specialite_id')
            ->whereIn('f.departement_id', $departments)
            ->when($request->filled('annee_id'), fn ($query) => $query->where('c.annee_id', $request->integer('annee_id')))
            ->orderBy('c.code_classe')->orderBy('ue.code_ue')->orderBy('m.rang_ec')
            ->get([
                'a.id', 'a.actif', 'a.enseignant_id', 'a.matiere_id', 'a.classe_id', 'u.nom', 'u.prenom', 'e.eid',
                'm.code_m', 'm.intitule_matiere', 'ue.code_ue', 'c.code_classe', 'an.libelle as annee_academique',
                'fac.code_fac', 'fac.nom_fac', 'd.code_de', 'd.nom_depart', 'n.libelle_niv', 'sp.libelle_specialite',
            ]);

        return response()->json(['data' => $rows]);
    }

    public function setAssignmentStatus(Request $request, int $affectation): JsonResponse
    {
        $data = $request->validate(['actif' => ['required', 'boolean']]);
        $departments = $this->departmentIds($request);
        $item = DB::table('gnu.affectation')->where('id', $affectation)->first();
        abort_unless($item !== null && $this->scope->hasClass($departments, (int) $item->classe_id), 404);
        abort_if((bool) $item->actif === $data['actif'], 409, 'L’affectation a déjà ce statut.');
        if ($data['actif']) {
            $conflict = DB::table('gnu.affectation as other')
                ->join('gnu.matiere as m', 'm.id', '=', 'other.matiere_id')
                ->join('gnu.enseignant as e', 'e.id', '=', 'other.enseignant_id')
                ->join('gnu.utilisateur as u', 'u.id', '=', 'e.utilisateur_id')
                ->where('other.classe_id', $item->classe_id)->where('other.matiere_id', $item->matiere_id)
                ->where('other.actif', true)->where('other.id', '<>', $affectation)
                ->first(['m.code_m', 'u.nom', 'u.prenom']);
            abort_if($conflict !== null, 409, 'Impossible de réactiver cette affectation : '.$conflict->code_m.' est déjà confié à '.$conflict->prenom.' '.$conflict->nom.' pour cette classe. Désactivez d’abord l’affectation active.');
        }

        DB::transaction(function () use ($request, $data, $affectation, $item): void {
            DB::table('gnu.classe')->where('id', $item->classe_id)->lockForUpdate()->first();
            if ($data['actif']) {
                abort_if(DB::table('gnu.affectation')->where('classe_id', $item->classe_id)
                    ->where('matiere_id', $item->matiere_id)->where('actif', true)
                    ->where('id', '<>', $affectation)->exists(), 409,
                    'Une autre affectation active existe pour cette matière et cette classe.');
                abort_if(DB::table('gnu.proposition_affectation_enseignant as p')
                    ->join('gnu.affectation as a', 'a.id', '=', 'p.affectation_id')
                    ->where('a.classe_id', $item->classe_id)->where('a.matiere_id', $item->matiere_id)
                    ->where('p.statut', 'EN_ATTENTE')->exists(), 409,
                    'Traitez la demande de l’enseignant avant d’activer manuellement cette affectation.');
            }
            $this->setAuditContext($request, $data['actif'] ? 'Réactivation d’une affectation pédagogique' : 'Fin d’une affectation pédagogique');
            DB::table('gnu.affectation')->where('id', $affectation)->update(['actif' => $data['actif'], 'updated_at' => now()]);
        });

        return response()->json(['message' => $data['actif'] ? 'Affectation réactivée.' : 'Affectation désactivée.']);
    }

    public function storeAssignment(Request $request): JsonResponse
    {
        $data = $request->validate([
            'enseignant_id' => ['required', 'integer', 'min:1'],
            'matiere_id' => ['required_without:matiere_ids', 'integer', 'min:1'],
            'matiere_ids' => ['required_without:matiere_id', 'array', 'min:1'],
            'matiere_ids.*' => ['integer', 'min:1', 'distinct'],
            'classe_id' => ['required', 'integer', 'min:1'],
        ]);
        $courseIds = array_values(array_unique(array_map('intval', $data['matiere_ids'] ?? [$data['matiere_id']])));
        $departments = $this->departmentIds($request);
        $class = DB::table('gnu.classe as c')->join('gnu.niveau as n', 'n.id', '=', 'c.niveau_id')
            ->join('gnu.filiere as f', 'f.id', '=', 'n.filiere_id')->where('c.id', $data['classe_id'])
            ->whereIn('f.departement_id', $departments)->first(['c.id', 'c.niveau_id', 'c.version_programme']);
        abort_unless($class !== null, 404);
        $teacher = DB::table('gnu.enseignant as e')->join('gnu.utilisateur as u', 'u.id', '=', 'e.utilisateur_id')
            ->where('e.id', $data['enseignant_id'])->where('u.role', 'ENSEIGNANT')->where('u.actif', true)->exists();
        abort_unless($teacher, 422, 'Enseignant actif introuvable.');
        $matchingCourses = DB::table('gnu.matiere as m')->join('gnu.ue as u', 'u.id', '=', 'm.ue_id')
            ->whereIn('m.id', $courseIds)->where('u.niveau_id', $class->niveau_id)
            ->where('u.version_programme', $class->version_programme)->where('u.statut_catalogue', 'ACTIF')
            ->distinct()->pluck('m.id')->map(static fn (mixed $id): int => (int) $id)->all();
        abort_unless(count($matchingCourses) === count($courseIds), 422, 'Un élément ne correspond pas au programme actif de la classe.');
        $activeConflicts = DB::table('gnu.affectation as a')
            ->join('gnu.matiere as m', 'm.id', '=', 'a.matiere_id')
            ->join('gnu.enseignant as e', 'e.id', '=', 'a.enseignant_id')
            ->join('gnu.utilisateur as u', 'u.id', '=', 'e.utilisateur_id')
            ->where('a.classe_id', $data['classe_id'])->whereIn('a.matiere_id', $courseIds)->where('a.actif', true)
            ->get(['m.code_m', 'u.nom', 'u.prenom']);
        abort_if($activeConflicts->isNotEmpty(), 409, 'Affectation impossible : '.$activeConflicts->map(fn (object $row) => $row->code_m.' est déjà confié à '.$row->prenom.' '.$row->nom)->implode(' ; ').' pour cette classe. Désactivez d’abord l’affectation active.');

        $inactiveDuplicates = DB::table('gnu.affectation as a')->join('gnu.matiere as m', 'm.id', '=', 'a.matiere_id')
            ->where('a.enseignant_id', $data['enseignant_id'])->where('a.classe_id', $data['classe_id'])
            ->whereIn('a.matiere_id', $courseIds)->where('a.actif', false)->pluck('m.code_m')->all();
        abort_if($inactiveDuplicates !== [], 409, 'Une ancienne affectation désactivée existe déjà pour : '.implode(', ', $inactiveDuplicates).'. Réactivez-la dans la liste au lieu d’en créer une nouvelle.');

        $ids = DB::transaction(function () use ($request, $data, $courseIds): array {
            DB::table('gnu.classe')->where('id', $data['classe_id'])->lockForUpdate()->first();
            $newConflicts = DB::table('gnu.affectation')->where('classe_id', $data['classe_id'])
                ->whereIn('matiere_id', $courseIds)->where('actif', true)->exists();
            abort_if($newConflicts, 409, 'Une matière sélectionnée vient d’être attribuée. Actualisez la liste.');
            abort_if(DB::table('gnu.proposition_affectation_enseignant as p')
                ->join('gnu.affectation as a', 'a.id', '=', 'p.affectation_id')
                ->where('a.classe_id', $data['classe_id'])->whereIn('a.matiere_id', $courseIds)
                ->where('p.statut', 'EN_ATTENTE')->exists(), 409,
                'Une demande enseignant est en attente pour une matière sélectionnée. Traitez-la avant de créer une affectation.');
            $this->setAuditContext($request, 'Affectation d’un enseignant à plusieurs EC d’une classe');
            $created = [];
            foreach ($courseIds as $courseId) {
                $created[] = (int) DB::table('gnu.affectation')->insertGetId([
                    'enseignant_id' => $data['enseignant_id'],
                    'matiere_id' => $courseId,
                    'classe_id' => $data['classe_id'],
                    'actif' => true,
                    'created_at' => now(),
                    'updated_at' => now(),
                ], 'id');
            }

            return $created;
        });

        return response()->json(['ids' => $ids, 'message' => count($ids).' affectation(s) créée(s).'], 201);
    }

    public function enrollments(Request $request): JsonResponse
    {
        $departments = $this->departmentIds($request);
        $rows = DB::table('gnu.inscription_semestre as s')
            ->join('gnu.inscription_classe as ic', 'ic.id', '=', 's.inscription_classe_id')
            ->join('gnu.etudiant as e', 'e.id', '=', 'ic.etudiant_id')
            ->join('gnu.utilisateur as u', 'u.id', '=', 'e.utilisateur_id')
            ->join('gnu.classe as c', 'c.id', '=', 'ic.classe_id')
            ->join('gnu.niveau as n', 'n.id', '=', 'c.niveau_id')
            ->join('gnu.filiere as f', 'f.id', '=', 'n.filiere_id')
            ->join('gnu.departement as d', 'd.id', '=', 'f.departement_id')
            ->whereIn('f.departement_id', $departments)
            ->when($request->filled('annee_id'), fn ($query) => $query->where('c.annee_id', $request->integer('annee_id')))
            ->when($request->query('statut'), fn ($query, string $status) => $query->where('s.statut', $status))
            ->orderByDesc('s.date_soumission')->get([
                's.id', 's.statut', 's.numero_semestre', 's.date_soumission', 'ic.id as inscription_classe_id',
                'e.id as etudiant_id', 'e.matricule', 'u.nom', 'u.prenom', 'c.id as classe_id', 'c.code_classe',
                'n.libelle_niv', 'f.code_f', 'd.nom_depart',
            ])->map(function (object $row): array {
                $path = 'fiches-academiques/'.$row->etudiant_id.'/'.$row->inscription_classe_id.'.pdf';
                $result = (array) $row;
                $result['fiche_academique_disponible'] = Storage::disk('local')->exists($path);

                return $result;
            });

        return response()->json(['data' => $rows]);
    }

    public function reviewEnrollment(Request $request, int $inscriptionSemestre): JsonResponse
    {
        $data = $this->normalizeOptionalMotif($request->validate([
            'decision' => ['required', 'in:VALIDER,REFUSER'],
            'motif' => ['nullable', 'string', 'min:8', 'max:1000'],
        ]));
        $departments = $this->departmentIds($request);
        $row = DB::table('gnu.inscription_semestre as s')
            ->join('gnu.inscription_classe as ic', 'ic.id', '=', 's.inscription_classe_id')
            ->join('gnu.classe as c', 'c.id', '=', 'ic.classe_id')
            ->join('gnu.niveau as n', 'n.id', '=', 'c.niveau_id')
            ->join('gnu.filiere as f', 'f.id', '=', 'n.filiere_id')
            ->where('s.id', $inscriptionSemestre)->whereIn('f.departement_id', $departments)
            ->first(['s.id', 's.statut', 's.numero_semestre', 's.inscription_classe_id']);
        abort_unless($row !== null, 404);
        abort_unless($row->statut === 'SOUMISE', 409, 'Seules les inscriptions soumises peuvent être examinées.');
        $student = DB::table('gnu.inscription_classe as ic')->join('gnu.etudiant as e', 'e.id', '=', 'ic.etudiant_id')
            ->join('gnu.utilisateur as u', 'u.id', '=', 'e.utilisateur_id')->where('ic.id', $row->inscription_classe_id)
            ->first(['u.id as user_id', 'e.matricule']);

        DB::transaction(function () use ($request, $data, $row, $student): void {
            $this->setAuditContext($request, $data['motif']);
            $newStatus = $data['decision'] === 'VALIDER' ? 'VALIDEE' : 'REFUSEE';
            DB::table('gnu.inscription_semestre')->where('id', $row->id)->where('statut', 'SOUMISE')
                ->update(['statut' => $newStatus, 'updated_at' => now()]);
            if ($newStatus === 'VALIDEE') {
                $unitIds = DB::table('gnu.inscription_ue as iu')->join('gnu.ue as ue', 'ue.id', '=', 'iu.ue_id')
                    ->where('iu.inscription_classe_id', $row->inscription_classe_id)
                    ->where('ue.numero_semestre', $row->numero_semestre)->where('iu.statut_inscription', 'BROUILLON')
                    ->pluck('iu.id');
                DB::table('gnu.inscription_ue')->whereIn('id', $unitIds)->update(['statut_inscription' => 'VALIDEE', 'updated_at' => now()]);
            }
            DB::table('gnu.notification')->insertOrIgnore([
                'destinataire_id' => $student->user_id,
                'type_notification' => 'INSCRIPTION_DECIDEE',
                'cle_evenement' => 'INSCRIPTION_SEMESTRE|'.$row->id.'|'.$newStatus,
                'contenu' => json_encode(['titre' => 'Décision sur votre inscription', 'message' => $data['motif'], 'statut' => $newStatus, 'semestre' => $row->numero_semestre], JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE),
                'date_envoi' => now(), 'statut_envoi' => 'ENVOYEE', 'created_at' => now(), 'updated_at' => now(),
            ]);
        });

        return response()->json(['message' => $data['decision'] === 'VALIDER' ? 'Inscription validée.' : 'Inscription renvoyée à l’étudiant.', 'statut' => $data['decision'] === 'VALIDER' ? 'VALIDEE' : 'REFUSEE']);
    }

    public function downloadAcademicSheet(Request $request, int $inscriptionClasse): mixed
    {
        $departments = $this->departmentIds($request);
        $context = DB::table('gnu.inscription_classe as ic')
            ->join('gnu.classe as c', 'c.id', '=', 'ic.classe_id')
            ->join('gnu.niveau as n', 'n.id', '=', 'c.niveau_id')
            ->join('gnu.filiere as f', 'f.id', '=', 'n.filiere_id')
            ->join('gnu.etudiant as e', 'e.id', '=', 'ic.etudiant_id')
            ->where('ic.id', $inscriptionClasse)->whereIn('f.departement_id', $departments)
            ->first(['e.id as etudiant_id', 'ic.id as inscription_classe_id']);
        abort_unless($context !== null, 404);
        $path = 'fiches-academiques/'.$context->etudiant_id.'/'.$context->inscription_classe_id.'.pdf';
        abort_unless(Storage::disk('local')->exists($path), 404, 'Aucune fiche académique importée pour cette inscription.');

        return Storage::disk('local')->download($path, 'fiche-academique-reference.pdf', [
            'Content-Type' => 'application/pdf',
        ]);
    }

    public function requests(Request $request): JsonResponse
    {
        $departments = $this->departmentIds($request);
        $rows = DB::table('gnu.requete as r')->join('gnu.inscription_ue as iu', 'iu.id', '=', 'r.inscription_ue_id')
            ->join('gnu.inscription_classe as ic', 'ic.id', '=', 'iu.inscription_classe_id')
            ->join('gnu.etudiant as e', 'e.id', '=', 'ic.etudiant_id')->join('gnu.utilisateur as student', 'student.id', '=', 'e.utilisateur_id')
            ->join('gnu.ue as ue', 'ue.id', '=', 'iu.ue_id')->join('gnu.classe as c', 'c.id', '=', 'ic.classe_id')
            ->join('gnu.niveau as n', 'n.id', '=', 'c.niveau_id')->join('gnu.filiere as f', 'f.id', '=', 'n.filiere_id')
            ->leftJoin('gnu.agent_requete_transmission as tr', function ($join): void {
                $join->on('tr.requete_id', '=', 'r.id')->where('tr.courante', '=', true);
            })
            ->leftJoin('gnu.enseignant as et', 'et.id', '=', 'tr.enseignant_id')
            ->leftJoin('gnu.utilisateur as assigned', 'assigned.id', '=', 'et.utilisateur_id')
            ->whereIn('f.departement_id', $departments)
            ->when($request->filled('annee_id'), fn ($query) => $query->where('c.annee_id', $request->integer('annee_id')))
            ->whereIn('r.statut_requete', ['SOUMISE', 'EN_TRAITEMENT'])
            ->whereNotExists(function ($query): void {
                $query->selectRaw('1')->from('gnu.decision_requete as d')
                    ->whereColumn('d.requete_id', 'r.id')->where('d.courante', true)
                    ->where('d.action_decision', 'AUTORISER_EVALUATION')
                    ->where('r.type_requete', 'NOTE_MANQUANTE');
            })
            ->orderBy('r.date_soumission')->get([
                'r.id', 'r.objet', 'r.description', 'r.type_requete', 'r.statut_requete', 'r.date_soumission', 'r.matiere_id',
                'e.matricule', 'student.nom as etudiant_nom', 'student.prenom as etudiant_prenom', 'ue.code_ue', 'c.id as classe_id', 'c.code_classe',
                'tr.enseignant_id', 'assigned.nom as enseignant_nom', 'assigned.prenom as enseignant_prenom', 'tr.motif as transmission_motif',
            ]);

        return response()->json(['data' => $rows]);
    }

    public function routeRequestToTeacher(Request $request, int $requete): JsonResponse
    {
        $data = $this->normalizeOptionalMotif($request->validate([
            'enseignant_id' => ['required', 'integer', 'min:1'],
            'motif' => ['nullable', 'string', 'min:8', 'max:500'],
        ]));
        $departments = $this->departmentIds($request);
        $item = DB::table('gnu.requete as r')->join('gnu.inscription_ue as iu', 'iu.id', '=', 'r.inscription_ue_id')
            ->join('gnu.inscription_classe as ic', 'ic.id', '=', 'iu.inscription_classe_id')->join('gnu.classe as c', 'c.id', '=', 'ic.classe_id')
            ->join('gnu.niveau as n', 'n.id', '=', 'c.niveau_id')->join('gnu.filiere as f', 'f.id', '=', 'n.filiere_id')
            ->where('r.id', $requete)->whereIn('f.departement_id', $departments)->first([
                'r.id', 'r.statut_requete', 'r.type_requete', 'r.matiere_id', 'iu.ue_id', 'c.id as classe_id',
            ]);
        abort_unless($item !== null, 404);
        abort_unless(in_array($item->statut_requete, ['SOUMISE', 'EN_TRAITEMENT'], true), 409, 'Cette requête est déjà décidée.');
        abort_if($item->type_requete === 'NOTE_MANQUANTE' && DB::table('gnu.decision_requete')
            ->where('requete_id', $item->id)->where('courante', true)->where('action_decision', 'AUTORISER_EVALUATION')->exists(),
            409, 'L’enseignant a déjà autorisé cette correction; elle doit maintenant suivre le circuit de validation.');
        abort_unless($item->matiere_id !== null, 409, 'La requête ne précise pas l’élément constitutif concerné et ne peut pas être transmise.');
        $assignment = DB::table('gnu.affectation as a')->join('gnu.enseignant as e', 'e.id', '=', 'a.enseignant_id')
            ->join('gnu.utilisateur as u', 'u.id', '=', 'e.utilisateur_id')->join('gnu.matiere as m', 'm.id', '=', 'a.matiere_id')
            ->where('a.enseignant_id', $data['enseignant_id'])->where('a.classe_id', $item->classe_id)->where('a.actif', true)
            ->where('m.id', $item->matiere_id)->where('u.actif', true)->first(['a.enseignant_id', 'u.id as user_id']);
        abort_unless($assignment !== null, 422, 'Cet enseignant ne possède pas d’affectation active pour la classe et l’UE.');

        DB::transaction(function () use ($request, $data, $item, $assignment): void {
            $this->setAuditContext($request, $data['motif']);
            abort_unless(DB::table('gnu.requete')->where('id', $item->id)->lockForUpdate()->value('id') !== null, 404);
            $status = DB::table('gnu.requete')->where('id', $item->id)->value('statut_requete');
            abort_unless(in_array($status, ['SOUMISE', 'EN_TRAITEMENT'], true), 409, 'Cette requête a déjà été traitée.');
            DB::table('gnu.agent_requete_transmission')->where('requete_id', $item->id)->where('courante', true)->update(['courante' => false]);
            $version = ((int) DB::table('gnu.agent_requete_transmission')->where('requete_id', $item->id)->max('version')) + 1;
            DB::table('gnu.agent_requete_transmission')->insert([
                'requete_id' => $item->id,
                'enseignant_id' => $assignment->enseignant_id,
                'agent_id' => $request->user()->id,
                'version' => $version,
                'motif' => $data['motif'],
                'courante' => true,
                'created_at' => now(),
            ]);
            if ($status === 'SOUMISE') {
                DB::table('gnu.requete')->where('id', $item->id)->update(['statut_requete' => 'EN_TRAITEMENT', 'updated_at' => now()]);
            }
            DB::table('gnu.notification')->insertOrIgnore([
                'destinataire_id' => $assignment->user_id,
                'requete_id' => $item->id,
                'type_notification' => 'REQUETE_DEPOSEE',
                'cle_evenement' => 'REQUETE|'.$item->id.'|AFFECTATION|'.$assignment->enseignant_id.'|V'.$version,
                'contenu' => json_encode(['titre' => 'Requête étudiante à examiner', 'message' => $data['motif'], 'requete_id' => $item->id], JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE),
                'date_envoi' => now(), 'statut_envoi' => 'ENVOYEE', 'created_at' => now(), 'updated_at' => now(),
            ]);
        });

        return response()->json(['message' => 'Requête transmise à l’enseignant affecté.']);
    }

    public function bulletinPreview(Request $request, int $classe): JsonResponse
    {
        $departments = $this->departmentIds($request);
        abort_unless($this->scope->hasClass($departments, $classe), 404);
        $period = $request->query('periode', 'S1');
        abort_unless(in_array($period, ['S1', 'S2', 'ANNUELLE'], true), 422, 'Période invalide.');
        $registrations = DB::table('gnu.inscription_classe as ic')
            ->join('gnu.etudiant as e', 'e.id', '=', 'ic.etudiant_id')
            ->join('gnu.utilisateur as u', 'u.id', '=', 'e.utilisateur_id')
            ->where('ic.classe_id', $classe)->where('ic.statut_inscription', 'VALIDEE')
            ->orderBy('e.matricule')->get(['ic.id', 'e.matricule', 'u.nom', 'u.prenom']);
        $class = DB::table('gnu.classe as c')->join('gnu.annee_academique as an', 'an.id', '=', 'c.annee_id')
            ->join('gnu.niveau as n', 'n.id', '=', 'c.niveau_id')
            ->join('gnu.filiere as f', 'f.id', '=', 'n.filiere_id')
            ->join('gnu.departement as d', 'd.id', '=', 'f.departement_id')
            ->join('gnu.faculte as fac', 'fac.id', '=', 'd.faculte_id')
            ->join('gnu.universite as un', 'un.id', '=', 'fac.universite_id')
            ->leftJoin('gnu.specialite as sp', 'sp.id', '=', 'n.specialite_id')
            ->where('c.id', $classe)->first([
                'c.code_classe', 'c.annee_id', 'c.niveau_id', 'c.version_programme',
                'an.libelle as annee_academique', 'n.code_niv', 'n.libelle_niv',
                'un.id as universite_id', 'un.nom_univ', 'fac.id as faculte_id', 'fac.nom_fac',
                'd.id as departement_id', 'd.nom_depart', 'f.nom_f as nom_filiere', 'sp.libelle_specialite',
            ]);
        $rows = [];
        $unitTitles = DB::table('gnu.ue')->where('niveau_id', $class->niveau_id)
            ->where('version_programme', $class->version_programme)->pluck('intitule_ue', 'id');
        $pendingTransmissions = DB::table('gnu.transmission_note as tn')->join('gnu.affectation as a', 'a.id', '=', 'tn.affectation_id')
            ->where('a.classe_id', $classe)->whereIn('tn.statut', ['TRANSMISE', 'A_VERIFIER', 'A_CORRIGER'])->count();
        $unverifiedEvaluations = $this->unverifiedGradeEvaluationCount($classe, $period);
        foreach ($registrations as $registration) {
            try {
                $result = DB::selectOne('SELECT gnu.calculer_bulletin(?, ?) AS contenu', [$registration->id, $period]);
                $content = is_string($result->contenu) ? json_decode($result->contenu, true, flags: JSON_THROW_ON_ERROR) : (array) $result->contenu;
                $content['ues'] = array_map(static function (array $unit) use ($unitTitles): array {
                    $unit['intitule_ue'] = $unitTitles[$unit['ue_id'] ?? 0] ?? '';

                    return $unit;
                }, $content['ues'] ?? []);
                $rows[] = ['inscription_classe_id' => (int) $registration->id, 'matricule' => $registration->matricule, 'nom' => $registration->nom, 'prenom' => $registration->prenom, 'pret' => true, 'contenu' => $content];
            } catch (Throwable) {
                $rows[] = ['inscription_classe_id' => (int) $registration->id, 'matricule' => $registration->matricule, 'nom' => $registration->nom, 'prenom' => $registration->prenom, 'pret' => false, 'message' => 'Notes, inscriptions ou validations incomplètes.'];
            }
        }
        $rows = $this->rankBulletinRows($rows, $period);

        return response()->json(['data' => [
            'classe_id' => $classe,
            'code_classe' => $class?->code_classe,
            'code_niveau' => $class?->code_niv,
            'niveau' => $class?->libelle_niv,
            'annee_id' => $class?->annee_id,
            'annee_academique' => $class?->annee_academique,
            'structure' => $class === null ? null : [
                'universite' => $class->nom_univ,
                'faculte' => $class->nom_fac,
                'departement' => $class->nom_depart,
                'filiere' => $class->nom_filiere,
                'niveau' => $class->libelle_niv,
                'specialite' => $class->libelle_specialite,
                'annee' => $class->annee_academique,
                'logo' => $this->structureLogo('departement_id', (int) $class->departement_id)
                    ?? $this->structureLogo('faculte_id', (int) $class->faculte_id)
                    ?? $this->structureLogo('universite_id', (int) $class->universite_id),
            ],
            'periode' => $period,
            'etudiants' => $rows,
            'pret' => $pendingTransmissions === 0 && $unverifiedEvaluations === 0 && $rows !== [] && collect($rows)->every(static fn (array $row): bool => $row['pret']),
            'transmissions_en_attente' => $pendingTransmissions,
            'evaluations_non_verifiees' => $unverifiedEvaluations,
            'peut_publier' => true,
            'publication_bloquee' => null,
            'version_courante' => DB::table('gnu.publication')->where('classe_id', $classe)->where('periode', $period)->max('version_publication'),
        ]]);
    }

    public function exportBulletins(Request $request, int $classe): mixed
    {
        $period = (string) $request->query('periode', 'S1');
        abort_unless(in_array($period, ['S1', 'S2', 'ANNUELLE'], true), 422, 'Période invalide.');
        $source = (string) $request->query('source', 'APERCU');
        abort_unless(in_array($source, ['APERCU', 'PUBLIE'], true), 422, 'Source du bulletin invalide.');
        $departments = $this->departmentIds($request);
        abort_unless($this->scope->hasClass($departments, $classe), 404);
        $class = DB::table('gnu.classe as c')->join('gnu.annee_academique as an', 'an.id', '=', 'c.annee_id')
            ->join('gnu.niveau as n', 'n.id', '=', 'c.niveau_id')
            ->where('c.id', $classe)->first(['c.code_classe', 'an.libelle as annee_academique', 'n.code_niv', 'n.libelle_niv']);
        abort_unless($class !== null, 404, 'Classe introuvable.');

        $publication = $source === 'PUBLIE'
            ? DB::table('gnu.publication')->where('classe_id', $classe)->where('periode', $period)
                ->orderByDesc('version_publication')->first(['id', 'version_publication'])
            : null;
        abort_if($source === 'PUBLIE' && $publication === null, 404, 'Aucune publication officielle n’existe pour cette période.');
        $published = $publication !== null;
        if ($published) {
            $rows = DB::table('gnu.bulletin as b')
                ->join('gnu.inscription_classe as ic', 'ic.id', '=', 'b.inscription_classe_id')
                ->join('gnu.etudiant as e', 'e.id', '=', 'ic.etudiant_id')
                ->join('gnu.utilisateur as u', 'u.id', '=', 'e.utilisateur_id')
                ->where('b.publication_id', $publication->id)->where('b.courant', true)
                ->orderBy('e.matricule')->get([
                    'ic.id as inscription_classe_id', 'e.matricule', 'u.nom', 'u.prenom', 'b.contenu_fige',
                    'b.mgp_s1', 'b.mgp_s2', 'b.mgp_total', 'b.total_credits', 'b.decision_admission',
                ])->map(static function (object $row): array {
                    $content = is_string($row->contenu_fige)
                        ? json_decode($row->contenu_fige, true, flags: JSON_THROW_ON_ERROR)
                        : (array) $row->contenu_fige;

                    return [
                        'inscription_classe_id' => (int) $row->inscription_classe_id,
                        'matricule' => $row->matricule,
                        'nom' => $row->nom,
                        'prenom' => $row->prenom,
                        'pret' => true,
                        'contenu' => $content,
                        'mgp_s1' => $row->mgp_s1,
                        'mgp_s2' => $row->mgp_s2,
                        'mgp_total' => $row->mgp_total,
                        'total_credits' => $row->total_credits,
                        'decision_admission' => $row->decision_admission,
                    ];
                })->all();
            $publicationVersion = (int) $publication->version_publication;
        } else {
            $preview = $this->bulletinPreview($request->merge(['periode' => $period]), $classe)->getData(true)['data'];
            $rows = $preview['etudiants'];
            $publicationVersion = null;
        }
        $rows = $this->rankBulletinRows($rows, $period);

        $summaryRows = [[
            'Rang', 'Matricule', 'Nom', 'Prénom', 'Classe', 'Niveau', 'Année académique', 'Période',
            'MGP S1', 'MGP S2', 'MGP annuelle', 'Total crédits', 'Décision', 'Statut',
        ]];
        $unitRows = [['Rang', 'Matricule', 'Nom', 'Prénom', 'Classe', 'Niveau', 'UE', 'Semestre', 'Crédits', 'Note /100', 'Note /20', 'Grade', 'Points MGP', 'Éliminatoire']];
        $elementRows = [['Rang', 'Matricule', 'Nom', 'Prénom', 'Classe', 'Niveau', 'UE', 'EC', 'Crédits', 'Note /100', 'Éliminatoire']];
        foreach ($rows as $row) {
            $content = $row['contenu'] ?? [];
            $mgpS1 = $row['mgp_s1'] ?? $content['mgp_s1'] ?? null;
            $mgpS2 = $row['mgp_s2'] ?? $content['mgp_s2'] ?? null;
            $mgpTotal = $row['mgp_total'] ?? $content['mgp_total'] ?? null;
            $totalCredits = $row['total_credits'] ?? $content['total_credits'] ?? null;
            $summaryRows[] = [
                $row['rang'] ?? '', $row['matricule'], $row['nom'], $row['prenom'] ?? '', $class->code_classe,
                $class->code_niv.' · '.$class->libelle_niv, $class->annee_academique, $period,
                is_numeric($mgpS1) ? (float) $mgpS1 : '', is_numeric($mgpS2) ? (float) $mgpS2 : '',
                is_numeric($mgpTotal) ? (float) $mgpTotal : '', is_numeric($totalCredits) ? (float) $totalCredits : '',
                $row['decision_admission'] ?? $content['decision_admission'] ?? '',
                $published ? 'Publié · version '.$publicationVersion : ($row['pret'] ? 'Aperçu prêt' : 'À compléter'),
            ];
            foreach ($content['ues'] ?? [] as $unit) {
                $unitRows[] = [
                    $row['rang'] ?? '', $row['matricule'], $row['nom'], $row['prenom'] ?? '', $class->code_classe,
                    $class->code_niv, $unit['code_ue'] ?? '', $unit['semestre'] ?? '', is_numeric($unit['credit'] ?? null) ? (float) $unit['credit'] : '',
                    is_numeric($unit['arrondi'] ?? null) ? (float) $unit['arrondi'] : '', is_numeric($unit['arrondi'] ?? null) ? round((float) $unit['arrondi'] / 5, 2) : '',
                    $unit['grade'] ?? '', is_numeric($unit['points'] ?? null) ? (float) $unit['points'] : '', ! empty($unit['el']) ? 'Oui' : 'Non',
                ];
                foreach ($unit['ecs'] ?? [] as $element) {
                    $elementRows[] = [
                        $row['rang'] ?? '', $row['matricule'], $row['nom'], $row['prenom'] ?? '', $class->code_classe,
                        $class->code_niv, $unit['code_ue'] ?? '', $element['code_m'] ?? '', is_numeric($element['credit'] ?? null) ? (float) $element['credit'] : '',
                        is_numeric($element['arrondi'] ?? null) ? (float) $element['arrondi'] : '', ! empty($element['el']) ? 'Oui' : 'Non',
                    ];
                }
            }
        }

        $content = app(GradeWorkbookWriter::class)->write([
            ['name' => 'Résultats', 'rows' => $summaryRows],
            ['name' => 'Notes par UE', 'rows' => $unitRows],
            ['name' => 'Notes par EC', 'rows' => $elementRows],
        ]);
        $filename = 'bulletins-'.$class->code_classe.'-'.$period.($published ? '-publie-v'.$publicationVersion : '-apercu').'.xlsx';
        $filename = trim(preg_replace('/[^A-Za-z0-9._-]+/', '-', $filename) ?? 'bulletins.xlsx', '-');

        return response()->streamDownload(static function () use ($content): void {
            echo $content;
        }, $filename, ['Content-Type' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet']);
    }

    /** @param list<array<string, mixed>> $rows @return list<array<string, mixed>> */
    private function rankBulletinRows(array $rows, string $period): array
    {
        $key = match ($period) {
            'S1' => 'mgp_s1', 'S2' => 'mgp_s2', default => 'mgp_total'
        };
        $rankable = [];
        foreach ($rows as $index => $row) {
            $value = $row[$key] ?? $row['contenu'][$key] ?? null;
            if (($row['pret'] ?? false) && is_numeric($value)) {
                $rankable[] = ['index' => $index, 'value' => (float) $value];
            }
        }
        usort($rankable, static fn (array $left, array $right): int => $right['value'] <=> $left['value']);
        $rank = 0;
        $previous = null;
        foreach ($rankable as $position => $item) {
            if ($previous === null || $item['value'] !== $previous) {
                $rank = $position + 1;
            }
            $rows[$item['index']]['rang'] = $rank;
            $previous = $item['value'];
        }
        foreach ($rows as $index => $row) {
            $rows[$index]['rang'] ??= null;
        }

        return $rows;
    }

    public function publish(Request $request, int $classe): JsonResponse
    {
        $data = $request->validate([
            'periode' => ['required', 'in:S1,S2,ANNUELLE'],
            'confirmer_nouvelle_version' => ['sometimes', 'boolean'],
        ]);
        $departments = $this->departmentIds($request);
        abort_unless($this->scope->hasClass($departments, $classe), 404);
        abort_unless($this->unverifiedGradeEvaluationCount($classe, $data['periode']) === 0, 409, 'Publication bloquée : chaque évaluation notée de la période doit suivre le circuit de contrôle et être vérifiée par son enseignant.');
        abort_unless(DB::table('gnu.transmission_note as tn')->join('gnu.affectation as a', 'a.id', '=', 'tn.affectation_id')
            ->where('a.classe_id', $classe)->whereIn('tn.statut', ['TRANSMISE', 'A_VERIFIER', 'A_CORRIGER'])->doesntExist(),
            409, 'Publication bloquée : des notes attendent le contrôle ou la vérification de l’enseignant.');
        $currentVersion = DB::table('gnu.publication')->where('classe_id', $classe)->where('periode', $data['periode'])->max('version_publication');
        abort_if($currentVersion !== null && ! ($data['confirmer_nouvelle_version'] ?? false), 409, 'Une publication existe déjà. Confirmez explicitement la création d’une nouvelle version.');

        $publicationId = DB::transaction(function () use ($request, $data, $classe): int {
            DB::statement('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ');
            $this->setAuditContext($request, 'Publication officielle des résultats '.$data['periode']);

            return (int) DB::scalar('SELECT gnu.publier_classe(?, ?) ', [$classe, $data['periode']]);
        });

        return response()->json(['id' => $publicationId, 'message' => 'Publication créée et bulletins figés.'], 201);
    }

    public function publicationRules(Request $request): JsonResponse
    {
        $rules = $this->officialPublicationRules();
        $hash = hash('sha256', json_encode($rules, JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES));

        return response()->json(['data' => [
            'regles' => $rules,
            'empreinte' => $hash,
            'source' => 'Règles académiques officielles de l’Université',
        ]]);
    }

    public function gradeTransmissions(Request $request): JsonResponse
    {
        $departments = $this->departmentIds($request);
        $rows = DB::table('gnu.transmission_note as tn')
            ->join('gnu.affectation as a', 'a.id', '=', 'tn.affectation_id')
            ->join('gnu.classe as c', 'c.id', '=', 'a.classe_id')
            ->join('gnu.niveau as n', 'n.id', '=', 'c.niveau_id')
            ->join('gnu.filiere as f', 'f.id', '=', 'n.filiere_id')
            ->join('gnu.matiere as m', 'm.id', '=', 'a.matiere_id')
            ->join('gnu.ue as ue', 'ue.id', '=', 'm.ue_id')
            ->leftJoin('gnu.plan_evaluation as pe', function ($join): void {
                $join->on('pe.affectation_id', '=', 'a.id')->where('pe.portee', '=', 'CLASSE')->where('pe.statut_plan', '=', 'ACTIF');
            })
            ->leftJoin('gnu.ligne_plan as lp', function ($join): void {
                $join->on('lp.plan_id', '=', 'pe.id')->on('lp.evaluation_id', '=', 'tn.evaluation_id')->where('lp.retenue', '=', true);
            })
            ->join('gnu.enseignant as ens', 'ens.id', '=', 'tn.enseignant_id')
            ->join('gnu.utilisateur as usr', 'usr.id', '=', 'ens.utilisateur_id')
            ->whereIn('f.departement_id', $departments)
            ->when($request->filled('annee_id'), fn ($query) => $query->where('c.annee_id', $request->integer('annee_id')))
            ->where('tn.statut', 'TRANSMISE')
            ->orderBy('tn.transmis_le')->get([
                'tn.id', 'tn.evaluation_id', 'tn.version', 'tn.statut', 'tn.transmis_le', 'tn.motif',
                'a.id as affectation_id', 'c.id as classe_id', 'c.code_classe', 'ue.code_ue', 'ue.intitule_ue', 'm.code_m', 'm.intitule_matiere',
                'usr.nom as enseignant_nom', 'usr.prenom as enseignant_prenom', 'ens.id as enseignant_id', 'lp.poids_evaluation',
            ]);
        foreach ($rows as $row) {
            $row->evaluation = DB::table('gnu.evaluation')->where('id', $row->evaluation_id)->first(['type_eval', 'date_evaluation']);
            $row->notes = DB::table('gnu.note as no')->join('gnu.inscription_ue as iu', 'iu.id', '=', 'no.inscription_ue_id')
                ->join('gnu.inscription_classe as ic', 'ic.id', '=', 'iu.inscription_classe_id')
                ->join('gnu.etudiant as e', 'e.id', '=', 'ic.etudiant_id')->join('gnu.utilisateur as u', 'u.id', '=', 'e.utilisateur_id')
                ->leftJoin('gnu.note_numerisee as nn', function ($join) use ($row): void {
                    $join->on('nn.inscription_ue_id', '=', 'iu.id')->where('nn.transmission_id', '=', $row->id);
                })
                ->where('no.evaluation_id', $row->evaluation_id)->where('ic.classe_id', $row->classe_id)
                ->orderBy('e.matricule')->get([
                    'iu.id as inscription_ue_id', 'no.id as note_id', 'no.version_note',
                    'e.matricule', 'u.nom', 'u.prenom', 'no.valeur_note', 'no.situation',
                    'nn.valeur_note as valeur_numerisee', 'nn.situation as situation_numerisee',
                    'nn.version_numerisation',
                ]);
        }

        return response()->json(['data' => $rows]);
    }

    public function digitizeGradeTransmission(Request $request, int $transmission): JsonResponse
    {
        $data = $this->normalizeOptionalMotif($request->validate([
            'motif' => ['nullable', 'string', 'min:8', 'max:1000'],
            'notes' => ['required', 'array', 'min:1', 'max:500'],
            'notes.*.matricule' => ['required', 'string', 'max:32', 'distinct'],
            'notes.*.situation' => ['required', 'in:NUMERIQUE,ABSENTE'],
            'notes.*.valeur_note' => ['nullable', 'numeric'],
            'notes.*.version_note' => ['required', 'integer', 'min:1'],
        ]));
        $data = $this->clampGradeInputs($data);
        $departments = $this->departmentIds($request);
        $item = DB::table('gnu.transmission_note as tn')->join('gnu.affectation as a', 'a.id', '=', 'tn.affectation_id')
            ->join('gnu.classe as c', 'c.id', '=', 'a.classe_id')->join('gnu.niveau as n', 'n.id', '=', 'c.niveau_id')
            ->join('gnu.filiere as f', 'f.id', '=', 'n.filiere_id')
            ->where('tn.id', $transmission)->whereIn('f.departement_id', $departments)
            ->first(['tn.id', 'tn.evaluation_id', 'tn.affectation_id', 'tn.statut', 'a.classe_id']);
        abort_unless($item !== null, 404, 'Transmission introuvable dans votre périmètre.');
        abort_unless($item->statut === 'TRANSMISE', 409, 'Seule une transmission en attente peut être numérisée.');

        $students = DB::table('gnu.note as no')->join('gnu.inscription_ue as iu', 'iu.id', '=', 'no.inscription_ue_id')
            ->join('gnu.inscription_classe as ic', 'ic.id', '=', 'iu.inscription_classe_id')
            ->join('gnu.etudiant as e', 'e.id', '=', 'ic.etudiant_id')
            ->where('no.evaluation_id', $item->evaluation_id)->where('ic.classe_id', $item->classe_id)
            ->whereIn('no.situation', ['NUMERIQUE', 'ABSENTE'])
            ->get(['e.matricule', 'iu.id as inscription_ue_id', 'no.version_note'])->keyBy(fn (object $row): string => strtoupper(trim($row->matricule)));
        abort_unless($students->count() === count($data['notes']), 422, 'La grille numérisée doit contenir exactement les étudiants de la transmission.');
        foreach ($data['notes'] as $index => $note) {
            $student = $students->get(strtoupper(trim($note['matricule'])));
            abort_unless($student !== null, 422, 'Le matricule '.$note['matricule'].' ne figure pas dans cette transmission.');
            abort_if((int) $student->version_note !== (int) $note['version_note'], 409, 'Une note a changé depuis le chargement. Rechargez la transmission.');
            if ($note['situation'] === 'NUMERIQUE' && (! isset($note['valeur_note']) || ! is_numeric($note['valeur_note']))) {
                throw ValidationException::withMessages(["notes.$index.valeur_note" => ['Une note numérique entre 0 et 20 est obligatoire.']]);
            }
            if ($note['situation'] === 'ABSENTE' && $note['valeur_note'] !== null) {
                throw ValidationException::withMessages(["notes.$index.valeur_note" => ['Une absence ne peut pas porter de valeur numérique.']]);
            }
        }

        DB::transaction(function () use ($request, $data, $item, $students): void {
            DB::table('gnu.affectation')->where('id', $item->affectation_id)->lockForUpdate()->first();
            $locked = DB::table('gnu.transmission_note')->where('id', $item->id)->lockForUpdate()->first();
            abort_unless($locked?->statut === 'TRANSMISE', 409, 'La transmission a déjà été retournée. Rechargez la file.');
            $this->setAuditContext($request, $data['motif']);
            foreach ($data['notes'] as $note) {
                $student = $students->get(strtoupper(trim($note['matricule'])));
                $values = [
                    'evaluation_id' => $item->evaluation_id,
                    'inscription_ue_id' => $student->inscription_ue_id,
                    'valeur_note' => $note['situation'] === 'NUMERIQUE' ? $note['valeur_note'] : null,
                    'situation' => $note['situation'],
                    'version_note_source' => $student->version_note,
                    'numerise_par' => $request->user()->id,
                    'motif' => trim($data['motif']),
                    'updated_at' => now(),
                ];
                $existing = DB::table('gnu.note_numerisee')->where('transmission_id', $item->id)
                    ->where('inscription_ue_id', $student->inscription_ue_id)->lockForUpdate()->first();
                if ($existing === null) {
                    DB::table('gnu.note_numerisee')->insert($values + [
                        'transmission_id' => $item->id,
                        'version_numerisation' => 1,
                        'created_at' => now(),
                    ]);
                } else {
                    DB::table('gnu.note_numerisee')->where('id', $existing->id)->update($values);
                }
            }
        });

        return response()->json(['enregistrements' => count($data['notes']), 'message' => 'Notes numérisées. Vous pouvez maintenant retourner la grille à l’enseignant pour vérification.']);
    }

    public function returnGradeTransmission(Request $request, int $transmission): JsonResponse
    {
        $data = $this->normalizeOptionalMotif($request->validate([
            'motif' => ['nullable', 'string', 'min:8', 'max:1000'],
        ]));
        $departments = $this->departmentIds($request);
        $row = DB::table('gnu.transmission_note as tn')->join('gnu.affectation as a', 'a.id', '=', 'tn.affectation_id')
            ->join('gnu.classe as c', 'c.id', '=', 'a.classe_id')->join('gnu.niveau as n', 'n.id', '=', 'c.niveau_id')
            ->join('gnu.filiere as f', 'f.id', '=', 'n.filiere_id')->where('tn.id', $transmission)->whereIn('f.departement_id', $departments)
            ->first(['tn.*']);
        abort_unless($row !== null, 404, 'Transmission introuvable dans votre périmètre.');
        abort_unless($row->statut === 'TRANSMISE', 409, 'Cette transmission n’attend pas le contrôle de la cellule.');
        DB::transaction(function () use ($request, $data, $transmission, $row): void {
            DB::table('gnu.affectation')->where('id', $row->affectation_id)->lockForUpdate()->first();
            $locked = DB::table('gnu.transmission_note')->where('id', $transmission)->lockForUpdate()->first();
            abort_unless($locked?->statut === 'TRANSMISE', 409, 'Cette transmission a déjà été traitée. Actualisez la file.');
            $expected = DB::table('gnu.note')->where('evaluation_id', $row->evaluation_id)->count();
            $digitized = DB::table('gnu.note_numerisee')->where('transmission_id', $transmission)->count();
            abort_unless($expected > 0 && $digitized === $expected, 409, 'Numérisez toutes les notes de la grille avant de la retourner à l’enseignant.');
            $this->setAuditContext($request, $data['motif']);
            DB::table('gnu.transmission_note')->where('id', $transmission)->update([
                'statut' => 'A_VERIFIER', 'traite_par' => $request->user()->id, 'traite_le' => now(),
                'motif' => trim($data['motif']), 'updated_at' => now(),
            ]);
        });

        return response()->json(['message' => 'Contrôle terminé. La transmission est retournée à l’enseignant pour vérification.']);
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

    private function unverifiedGradeEvaluationCount(int $classe, string $period): int
    {
        $latest = DB::table('gnu.transmission_note')->select('evaluation_id')->selectRaw('MAX(version) AS version')->groupBy('evaluation_id');

        return (int) DB::table('gnu.evaluation as ev')
            ->join('gnu.affectation as a', 'a.id', '=', 'ev.affectation_id')
            ->join('gnu.matiere as m', 'm.id', '=', 'a.matiere_id')
            ->join('gnu.ue as ue', 'ue.id', '=', 'm.ue_id')
            ->join('gnu.note as no', 'no.evaluation_id', '=', 'ev.id')
            ->leftJoinSub($latest, 'latest', function ($join): void {
                $join->on('latest.evaluation_id', '=', 'ev.id');
            })
            ->leftJoin('gnu.transmission_note as tn', function ($join): void {
                $join->on('tn.evaluation_id', '=', 'latest.evaluation_id')->on('tn.version', '=', 'latest.version');
            })
            ->where('a.classe_id', $classe)
            ->when($period !== 'ANNUELLE', fn ($query) => $query->where('ue.numero_semestre', substr($period, 1)))
            ->whereIn('no.statut_note', ['BROUILLON', 'VALIDEE'])
            ->where(function ($query): void {
                $query->whereNull('tn.id')->orWhere('tn.statut', '<>', 'VERIFIEE');
            })
            ->distinct('ev.id')->count('ev.id');
    }

    public function audit(Request $request): JsonResponse
    {
        $departments = $this->departmentIds($request);
        $classIds = $this->classesQuery($departments)
            ->when($request->filled('annee_id'), fn ($query) => $query->where('c.annee_id', $request->integer('annee_id')))
            ->pluck('c.id')->all();
        $levelIds = DB::table('gnu.niveau as n')->join('gnu.filiere as f', 'f.id', '=', 'n.filiere_id')->whereIn('f.departement_id', $departments)->pluck('n.id')->all();
        $unitIds = DB::table('gnu.ue as u')->whereIn('u.niveau_id', $levelIds)->pluck('u.id')->all();
        $courseIds = DB::table('gnu.matiere')->whereIn('ue_id', $unitIds)->pluck('id')->all();
        $registrationIds = DB::table('gnu.inscription_classe')->whereIn('classe_id', $classIds)->pluck('id')->all();
        $assignmentIds = DB::table('gnu.affectation')->whereIn('classe_id', $classIds)->pluck('id')->all();
        $userIds = $this->scope->visibleUserIds($departments);
        $relatedIds = [
            'departement' => $departments,
            'filiere' => DB::table('gnu.filiere')->whereIn('departement_id', $departments)->pluck('id')->all(),
            'niveau' => $levelIds,
            'classe' => $classIds, 'ue' => $unitIds, 'matiere' => $courseIds,
            'inscription_classe' => $registrationIds, 'affectation' => $assignmentIds,
            'utilisateur' => $userIds,
            'inscription_ue' => DB::table('gnu.inscription_ue')->whereIn('inscription_classe_id', $registrationIds)->pluck('id')->all(),
            'evaluation' => DB::table('gnu.evaluation')->whereIn('affectation_id', $assignmentIds)->pluck('id')->all(),
            'note' => DB::table('gnu.note as no')->join('gnu.evaluation as ev', 'ev.id', '=', 'no.evaluation_id')->whereIn('ev.affectation_id', $assignmentIds)->pluck('no.id')->all(),
            'requete' => DB::table('gnu.requete as r')->join('gnu.inscription_ue as iu', 'iu.id', '=', 'r.inscription_ue_id')->whereIn('iu.inscription_classe_id', $registrationIds)->pluck('r.id')->all(),
            'requete_rattrapage' => DB::table('gnu.requete_rattrapage as rr')
                ->join('gnu.requete as r', 'r.id', '=', 'rr.requete_id')
                ->join('gnu.inscription_ue as iu', 'iu.id', '=', 'r.inscription_ue_id')
                ->whereIn('iu.inscription_classe_id', $registrationIds)->pluck('rr.requete_id')->all(),
            'publication' => DB::table('gnu.publication')->whereIn('classe_id', $classIds)->pluck('id')->all(),
            'bulletin' => DB::table('gnu.bulletin')->whereIn('inscription_classe_id', $registrationIds)->pluck('id')->all(),
            'inscription_semestre' => DB::table('gnu.inscription_semestre')->whereIn('inscription_classe_id', $registrationIds)->pluck('id')->all(),
            'session_rattrapage' => DB::table('gnu.session_rattrapage')->whereIn('classe_id', $classIds)->pluck('id')->all(),
            'session_rattrapage_ue' => DB::table('gnu.session_rattrapage_ue as su')->join('gnu.session_rattrapage as s', 's.id', '=', 'su.session_id')->whereIn('s.classe_id', $classIds)->pluck('su.id')->all(),
            'agent_requete_transmission' => DB::table('gnu.agent_requete_transmission as tr')
                ->join('gnu.requete as r', 'r.id', '=', 'tr.requete_id')
                ->join('gnu.inscription_ue as iu', 'iu.id', '=', 'r.inscription_ue_id')
                ->whereIn('iu.inscription_classe_id', $registrationIds)->pluck('tr.id')->all(),
        ];
        $query = DB::table('gnu.journal_audit')->where(function ($outer) use ($relatedIds, $request): void {
            $outer->where('acteur_id', $request->user()->id);
            foreach ($relatedIds as $type => $ids) {
                if ($ids !== []) {
                    $outer->orWhere(function ($inner) use ($type, $ids): void {
                        $inner->where('type_objet', $type)->whereIn('identifiant_objet', $ids);
                    });
                }
            }
        });
        $rows = $query->orderByDesc('date_action')->limit(min(max($request->integer('limit', 100), 1), 250))->get([
            'id', 'acteur_id', 'origine', 'action', 'date_action', 'type_objet', 'identifiant_objet', 'avant', 'apres', 'motif',
        ]);

        return response()->json(['data' => $rows]);
    }

    public function sessions(Request $request): JsonResponse
    {
        $departments = $this->departmentIds($request);
        $rows = DB::table('gnu.session_rattrapage as s')->join('gnu.classe as c', 'c.id', '=', 's.classe_id')
            ->join('gnu.niveau as n', 'n.id', '=', 'c.niveau_id')->join('gnu.filiere as f', 'f.id', '=', 'n.filiere_id')
            ->leftJoin('gnu.session_rattrapage_ue as su', 'su.session_id', '=', 's.id')
            ->leftJoin('gnu.ue as ue', 'ue.id', '=', 'su.ue_id')
            ->whereIn('f.departement_id', $departments)
            ->when($request->filled('annee_id'), fn ($query) => $query->where('c.annee_id', $request->integer('annee_id')))
            ->orderBy('s.date_session')->get([
                's.id', 's.classe_id', 'c.code_classe', 'ue.id as ue_id', 'ue.code_ue', 'ue.intitule_ue',
                's.libelle', 's.date_session', 's.heure_debut', 's.heure_fin', 's.salle', 's.statut_session',
            ]);

        return response()->json(['data' => $rows]);
    }

    public function normalExamSessions(Request $request): JsonResponse
    {
        $departments = $this->departmentIds($request);
        $rows = DB::table('gnu.evaluation as ev')
            ->join('gnu.affectation as a', 'a.id', '=', 'ev.affectation_id')
            ->join('gnu.enseignant as ens', 'ens.id', '=', 'a.enseignant_id')
            ->join('gnu.utilisateur as teacher', 'teacher.id', '=', 'ens.utilisateur_id')
            ->join('gnu.classe as c', 'c.id', '=', 'a.classe_id')
            ->join('gnu.niveau as n', 'n.id', '=', 'c.niveau_id')
            ->join('gnu.filiere as f', 'f.id', '=', 'n.filiere_id')
            ->join('gnu.matiere as m', 'm.id', '=', 'a.matiere_id')
            ->join('gnu.ue as u', 'u.id', '=', 'm.ue_id')
            ->join('gnu.annee_academique as an', 'an.id', '=', 'c.annee_id')
            ->whereIn('f.departement_id', $departments)
            ->where('ev.type_eval', 'SN')->where('ev.mode_evaluation', 'NORMALE')
            ->where('a.actif', true)
            ->when($request->filled('annee_id'), fn ($query) => $query->where('c.annee_id', $request->integer('annee_id')))
            ->orderBy('ev.date_evaluation')->orderBy('c.code_classe')->orderBy('u.code_ue')
            ->get([
                'ev.id as evaluation_id', 'ev.date_evaluation', 'ev.heure_debut', 'ev.heure_fin', 'ev.salle',
                'a.id as affectation_id', 'a.enseignant_id', 'teacher.id as enseignant_utilisateur_id',
                'teacher.nom as enseignant_nom', 'teacher.prenom as enseignant_prenom',
                'c.id as classe_id', 'c.code_classe', 'n.libelle_niv', 'an.libelle as annee_academique',
                'u.id as ue_id', 'u.code_ue', 'u.intitule_ue', 'm.code_m', 'm.intitule_matiere',
            ]);

        return response()->json(['data' => $rows]);
    }

    public function scheduleNormalExam(Request $request, int $evaluation): JsonResponse
    {
        $request->merge(['salle' => strtoupper(trim((string) $request->input('salle')))]);
        $data = $request->validate([
            'date_evaluation' => ['required', 'date', 'after_or_equal:today'],
            'heure_debut' => ['required', 'date_format:H:i'],
            'heure_fin' => ['required', 'date_format:H:i', 'after:heure_debut'],
            'salle' => ['required', 'string', 'max:32', 'regex:/^[A-Z0-9][A-Z0-9-]{0,31}$/'],
        ], [
            'date_evaluation.after_or_equal' => 'La date de la session doit être aujourd’hui ou ultérieure.',
        ]);
        $departments = $this->departmentIds($request);
        $item = DB::table('gnu.evaluation as ev')
            ->join('gnu.affectation as a', 'a.id', '=', 'ev.affectation_id')
            ->join('gnu.classe as c', 'c.id', '=', 'a.classe_id')
            ->join('gnu.niveau as n', 'n.id', '=', 'c.niveau_id')
            ->join('gnu.filiere as f', 'f.id', '=', 'n.filiere_id')
            ->join('gnu.enseignant as ens', 'ens.id', '=', 'a.enseignant_id')
            ->join('gnu.utilisateur as teacher', 'teacher.id', '=', 'ens.utilisateur_id')
            ->join('gnu.matiere as m', 'm.id', '=', 'a.matiere_id')
            ->where('ev.id', $evaluation)->where('ev.type_eval', 'SN')->where('ev.mode_evaluation', 'NORMALE')
            ->where('a.actif', true)->whereIn('f.departement_id', $departments)
            ->first([
                'ev.id', 'ev.date_evaluation', 'a.id as affectation_id',
                'a.enseignant_id', 'a.classe_id', 'teacher.id as enseignant_utilisateur_id',
                'm.ue_id', 'm.code_m', 'c.code_classe',
            ]);
        abort_unless($item !== null, 404, 'Session normale introuvable dans votre périmètre.');

        DB::transaction(function () use ($request, $data, $item, $evaluation): void {
            $this->lockExamSlots($data['date_evaluation'], $data['salle'], (int) $item->classe_id, (int) $item->enseignant_id);
            DB::table('gnu.evaluation')->where('id', $evaluation)->lockForUpdate()->first();
            $this->assertExamSlotAvailable($data, $item, $evaluation);
            $this->setAuditContext($request, 'Planification agent d’une session normale');
            DB::table('gnu.evaluation')->where('id', $evaluation)->update([
                'date_evaluation' => $data['date_evaluation'],
                'heure_debut' => $data['heure_debut'],
                'heure_fin' => $data['heure_fin'],
                'salle' => $data['salle'],
                'programme_par' => $request->user()->id,
                'statut_evaluation' => 'PROGRAMMEE',
                'updated_at' => now(),
            ]);

            $recipients = DB::table('gnu.inscription_classe as ic')
                ->join('gnu.etudiant as e', 'e.id', '=', 'ic.etudiant_id')
                ->join('gnu.inscription_ue as iu', function ($join) use ($item): void {
                    $join->on('iu.inscription_classe_id', '=', 'ic.id')
                        ->where('iu.ue_id', '=', $item->ue_id)
                        ->where('iu.statut_inscription', '=', 'VALIDEE');
                })
                ->where('ic.classe_id', $item->classe_id)->where('ic.statut_inscription', 'VALIDEE')
                ->pluck('e.utilisateur_id')->push((int) $item->enseignant_utilisateur_id)->unique();
            $content = json_encode([
                'titre' => 'Session normale programmée',
                'message' => "{$item->code_m} · {$item->code_classe} : le {$data['date_evaluation']} de {$data['heure_debut']} à {$data['heure_fin']}, salle {$data['salle']}.",
                'evaluation_id' => $evaluation,
                'classe_id' => $item->classe_id,
                'affectation_id' => $item->affectation_id,
                'date' => $data['date_evaluation'],
                'heure_debut' => $data['heure_debut'],
                'heure_fin' => $data['heure_fin'],
                'salle' => $data['salle'],
            ], JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE);
            foreach ($recipients as $recipientId) {
                DB::table('gnu.notification')->insertOrIgnore([
                    'destinataire_id' => $recipientId,
                    'type_notification' => 'SESSION_NORMALE',
                    'cle_evenement' => 'SESSION_NORMALE|'.$evaluation.'|'.$data['date_evaluation'].'|'.$data['heure_debut'].'|'.$data['salle'],
                    'contenu' => $content,
                    'date_envoi' => now(),
                    'statut_envoi' => 'ENVOYEE',
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);
            }
        });

        return response()->json(['message' => 'Session normale planifiée. L’enseignant et les étudiants inscrits ont été notifiés.']);
    }

    /** @param array{date_evaluation: string, heure_debut: string, heure_fin: string, salle: string} $data */
    private function assertExamSlotAvailable(array $data, object $item, int $evaluation): void
    {
        $roomOccupied = DB::table('gnu.evaluation')->where('id', '<>', $evaluation)
            ->whereDate('date_evaluation', $data['date_evaluation'])->where('salle', $data['salle'])
            ->whereNotNull('heure_debut')->whereRaw('heure_debut < ? AND heure_fin > ?', [$data['heure_fin'], $data['heure_debut']])
            ->exists() || DB::table('gnu.session_rattrapage')->whereDate('date_session', $data['date_evaluation'])
            ->where('salle', $data['salle'])->whereNotNull('heure_debut')
            ->whereRaw('heure_debut < ? AND heure_fin > ?', [$data['heure_fin'], $data['heure_debut']])->exists();
        abort_if($roomOccupied, 409, 'Cette salle est déjà occupée sur ce créneau.');

        $classOccupied = DB::table('gnu.evaluation as ev')->join('gnu.affectation as a', 'a.id', '=', 'ev.affectation_id')
            ->where('a.classe_id', $item->classe_id)->where('ev.id', '<>', $evaluation)
            ->whereDate('ev.date_evaluation', $data['date_evaluation'])->whereNotNull('ev.heure_debut')
            ->whereRaw('ev.heure_debut < ? AND ev.heure_fin > ?', [$data['heure_fin'], $data['heure_debut']])->exists()
            || DB::table('gnu.session_rattrapage')->where('classe_id', $item->classe_id)
                ->whereDate('date_session', $data['date_evaluation'])->whereNotNull('heure_debut')
                ->whereRaw('heure_debut < ? AND heure_fin > ?', [$data['heure_fin'], $data['heure_debut']])->exists();
        abort_if($classOccupied, 409, 'Cette classe a déjà une évaluation sur ce créneau.');

        $teacherOccupied = DB::table('gnu.evaluation as ev')
            ->join('gnu.affectation as a', 'a.id', '=', 'ev.affectation_id')
            ->where('a.enseignant_id', $item->enseignant_id)->where('ev.id', '<>', $evaluation)
            ->whereDate('ev.date_evaluation', $data['date_evaluation'])->whereNotNull('ev.heure_debut')
            ->whereRaw('ev.heure_debut < ? AND ev.heure_fin > ?', [$data['heure_fin'], $data['heure_debut']])->exists()
            || DB::table('gnu.session_rattrapage as sr')
                ->join('gnu.session_rattrapage_ue as sru', 'sru.session_id', '=', 'sr.id')
                ->join('gnu.matiere as rm', 'rm.ue_id', '=', 'sru.ue_id')
                ->join('gnu.affectation as ra', function ($join): void {
                    $join->on('ra.classe_id', '=', 'sr.classe_id')->on('ra.matiere_id', '=', 'rm.id')->where('ra.actif', '=', true);
                })
                ->where('ra.enseignant_id', $item->enseignant_id)->whereDate('sr.date_session', $data['date_evaluation'])
                ->whereNotNull('sr.heure_debut')->whereRaw('sr.heure_debut < ? AND sr.heure_fin > ?', [$data['heure_fin'], $data['heure_debut']])->exists();
        abort_if($teacherOccupied, 409, 'L’enseignant est déjà programmé sur ce créneau.');
    }

    public function lockExamSlots(string $date, string $room, int $classId, int $teacherId): void
    {
        DB::select('SELECT pg_advisory_xact_lock(hashtext(?))', ['gnu.schedule.room|'.$date.'|'.$room]);
        DB::select('SELECT pg_advisory_xact_lock(hashtext(?))', ['gnu.schedule.class|'.$date.'|'.$classId]);
        DB::select('SELECT pg_advisory_xact_lock(hashtext(?))', ['gnu.schedule.teacher|'.$date.'|'.$teacherId]);
    }

    public function storeSession(Request $request): JsonResponse
    {
        $data = $request->validate([
            'classe_id' => ['required', 'integer', 'min:1'], 'libelle' => ['required', 'string', 'max:255'],
            'ue_id' => ['required', 'integer', 'min:1'],
            'date_session' => ['required', 'date', 'after_or_equal:today'],
        ]);
        abort_unless($this->scope->hasClass($this->departmentIds($request), (int) $data['classe_id']), 404);
        $unit = DB::table('gnu.ue as ue')->join('gnu.classe as c', function ($join): void {
            $join->on('c.niveau_id', '=', 'ue.niveau_id')->on('c.version_programme', '=', 'ue.version_programme');
        })->where('ue.id', $data['ue_id'])->where('c.id', $data['classe_id'])->where('ue.statut_catalogue', 'ACTIF')
            ->where('ue.categorie_ue', 'FONDAMENTALE')->first(['ue.id', 'ue.code_ue', 'ue.numero_semestre']);
        abort_unless($unit !== null, 422, 'L’UE doit être active, fondamentale et appartenir au programme de cette classe.');
        abort_unless($this->hasReceivedGradeForUnit((int) $data['classe_id'], (int) $unit->id), 422, 'Aucune grille de notes n’a encore été transmise pour cette UE.');
        if ($this->hasOfficialBulletinForUnit((int) $data['classe_id'], $unit)) {
            abort_unless(($this->eligibleRetakeStudentCounts((int) $data['classe_id'], [$unit])[(int) $unit->id] ?? 0) > 0, 422, 'Le bulletin officiel courant ne contient aucun étudiant admissible à ce rattrapage.');
        }
        $id = DB::transaction(function () use ($request, $data): int {
            $this->setAuditContext($request, 'Planification d’une session de rattrapage');
            $sessionId = (int) DB::table('gnu.session_rattrapage')->insertGetId([
                'classe_id' => $data['classe_id'],
                'libelle' => trim($data['libelle']), 'date_session' => $data['date_session'],
                'statut_session' => 'PREVUE', 'created_at' => now(), 'updated_at' => now(),
            ], 'id');
            DB::table('gnu.session_rattrapage_ue')->insert([
                'session_id' => $sessionId, 'ue_id' => $data['ue_id'], 'statut_session' => 'PREVUE',
                'created_at' => now(), 'updated_at' => now(),
            ]);

            return $sessionId;
        });

        return response()->json(['id' => $id, 'message' => 'Session planifiée.'], 201);
    }

    public function setSessionStatus(Request $request, int $session): JsonResponse
    {
        $data = $request->validate(['statut_session' => ['required', 'in:OUVERTE,CLOTUREE,ANNULEE']]);
        $departments = $this->departmentIds($request);
        $item = DB::table('gnu.session_rattrapage')->where('id', $session)->first();
        abort_unless($item !== null && $this->scope->hasClass($departments, (int) $item->classe_id), 404);
        $allowed = match ($item->statut_session) {
            'PREVUE' => ['OUVERTE', 'ANNULEE'],
            'OUVERTE' => ['CLOTUREE', 'ANNULEE'],
            default => [],
        };
        abort_unless(in_array($data['statut_session'], $allowed, true), 409, 'Transition de session non autorisée.');

        DB::transaction(function () use ($request, $data, $session): void {
            $this->setAuditContext($request, 'Changement du statut d’une session de rattrapage');
            DB::table('gnu.session_rattrapage')->where('id', $session)->update(['statut_session' => $data['statut_session'], 'updated_at' => now()]);
            DB::table('gnu.session_rattrapage_ue')->where('session_id', $session)->update([
                'statut_session' => $data['statut_session'], 'updated_at' => now(),
            ]);
        });

        return response()->json(['message' => 'Statut de session mis à jour.']);
    }

    public function retakeOpportunities(Request $request): JsonResponse
    {
        $departments = $this->departmentIds($request);
        $classes = $this->classesQuery($departments)
            ->when($request->filled('annee_id'), fn ($query) => $query->where('c.annee_id', $request->integer('annee_id')))
            ->get(['c.id', 'c.code_classe', 'c.niveau_id', 'c.version_programme']);
        $opportunities = [];
        foreach ($classes as $class) {
            $units = DB::table('gnu.ue')->where('niveau_id', $class->niveau_id)
                ->where('version_programme', $class->version_programme)->where('statut_catalogue', 'ACTIF')
                ->where('categorie_ue', 'FONDAMENTALE')->orderBy('numero_semestre')->orderBy('code_ue')->get([
                    'id', 'code_ue', 'intitule_ue', 'numero_semestre', 'credit_ue',
                ]);
            $receivedUnitIds = DB::table('gnu.transmission_note as tn')->join('gnu.affectation as a', 'a.id', '=', 'tn.affectation_id')
                ->join('gnu.matiere as m', 'm.id', '=', 'a.matiere_id')->where('a.classe_id', $class->id)
                ->whereIn('tn.statut', ['TRANSMISE', 'A_VERIFIER', 'VERIFIEE'])->distinct()->pluck('m.ue_id')
                ->map(static fn (mixed $id): int => (int) $id)->flip();
            $officialPeriods = DB::table('gnu.bulletin as b')->join('gnu.inscription_classe as ic', 'ic.id', '=', 'b.inscription_classe_id')
                ->where('ic.classe_id', $class->id)->where('b.courant', true)->pluck('b.periode')->unique()->all();
            $eligibleCounts = $officialPeriods === [] ? [] : $this->eligibleRetakeStudentCounts((int) $class->id, $units->all());
            foreach ($units as $unit) {
                if (! $receivedUnitIds->has((int) $unit->id)) {
                    continue;
                }
                $hasOfficialBulletin = in_array('ANNUELLE', $officialPeriods, true)
                    || in_array('S'.$unit->numero_semestre, $officialPeriods, true);
                $candidateCount = $hasOfficialBulletin ? ($eligibleCounts[(int) $unit->id] ?? 0) : null;
                if (! $hasOfficialBulletin || $candidateCount > 0) {
                    $opportunities[] = [
                        'classe_id' => (int) $class->id, 'code_classe' => $class->code_classe,
                        'ue_id' => (int) $unit->id, 'code_ue' => $unit->code_ue, 'intitule_ue' => $unit->intitule_ue,
                        'semestre' => (int) $unit->numero_semestre, 'credits' => (float) $unit->credit_ue,
                        'etudiants_eligibles' => $candidateCount,
                        'eligibilite_confirmee' => $hasOfficialBulletin,
                    ];
                }
            }
        }

        return response()->json(['data' => $opportunities]);
    }

    /** @param array<int, object> $units
     * @return array<int, int>
     */
    private function eligibleRetakeStudentCounts(int $classId, array $units): array
    {
        if ($units === []) {
            return [];
        }
        $unitIds = array_map(static fn (object $unit): int => (int) $unit->id, $units);
        $registrations = DB::table('gnu.inscription_ue as iu')->join('gnu.inscription_classe as ic', 'ic.id', '=', 'iu.inscription_classe_id')
            ->where('ic.classe_id', $classId)->where('ic.statut_inscription', 'VALIDEE')->whereIn('iu.ue_id', $unitIds)
            ->where('iu.statut_inscription', 'VALIDEE')->get(['iu.id', 'iu.ue_id', 'ic.etudiant_id']);
        $registrationByStudentAndUnit = $registrations->keyBy(fn (object $row): string => $row->etudiant_id.':'.$row->ue_id);
        $registrationIds = $registrations->pluck('id')->all();
        $bulletins = DB::table('gnu.bulletin as b')->join('gnu.inscription_classe as ic', 'ic.id', '=', 'b.inscription_classe_id')
            ->where('ic.classe_id', $classId)->where('ic.statut_inscription', 'VALIDEE')->where('b.courant', true)
            ->whereIn('b.periode', ['S1', 'S2', 'ANNUELLE'])->get(['b.id as bulletin_id', 'b.periode', 'b.inscription_classe_id', 'b.contenu_fige', 'ic.etudiant_id']);
        $candidatures = $registrationIds === [] || $bulletins->isEmpty() ? collect() : DB::table('gnu.candidature_rattrapage')
            ->whereIn('inscription_ue_id', $registrationIds)->whereIn('bulletin_source_id', $bulletins->pluck('bulletin_id')->all())
            ->where('statut_candidature', '<>', 'ANNULEE')->get(['etudiant_id', 'inscription_ue_id', 'bulletin_source_id', 'session_id'])
            ->groupBy(fn (object $row): string => $row->etudiant_id.':'.$row->inscription_ue_id.':'.$row->bulletin_source_id);
        $seenStudentsByUnit = [];
        $counts = [];
        $rules = app(AcademicRules::class);
        foreach ($units as $unit) {
            $period = 'S'.$unit->numero_semestre;
            $seenStudentsByUnit[(int) $unit->id] = [];
            $resolvedStudents = [];
            $orderedBulletins = $bulletins->sortBy(static fn (object $bulletin): int => $bulletin->periode === $period ? 0 : 1);
            foreach ($orderedBulletins as $bulletin) {
                $studentId = (int) $bulletin->etudiant_id;
                if (isset($resolvedStudents[$studentId])) {
                    continue;
                }
                $snapshot = is_string($bulletin->contenu_fige) ? json_decode($bulletin->contenu_fige, true) : (array) $bulletin->contenu_fige;
                $mark = $rules->markForUnitSnapshot($snapshot, $unit->code_ue);
                $registration = $registrationByStudentAndUnit->get($studentId.':'.$unit->id);
                if ($mark === null || $registration === null) {
                    continue;
                }
                $resolvedStudents[$studentId] = true;
                $candidateKey = $studentId.':'.$registration->id.':'.$bulletin->bulletin_id;
                $existingCount = $candidatures->get($candidateKey, collect())
                    ->filter(fn (object $candidate): bool => $candidate->session_id !== null)
                    ->pluck('session_id')->unique()->count();
                if ($rules->isRetakeEligible($mark, $existingCount)) {
                    $seenStudentsByUnit[(int) $unit->id][$studentId] = true;
                }
            }
            $counts[(int) $unit->id] = count($seenStudentsByUnit[(int) $unit->id]);
        }

        return $counts;
    }

    private function hasReceivedGradeForUnit(int $classId, int $unitId): bool
    {
        return DB::table('gnu.transmission_note as tn')->join('gnu.affectation as a', 'a.id', '=', 'tn.affectation_id')
            ->join('gnu.matiere as m', 'm.id', '=', 'a.matiere_id')->where('a.classe_id', $classId)
            ->where('m.ue_id', $unitId)->whereIn('tn.statut', ['TRANSMISE', 'A_VERIFIER', 'VERIFIEE'])->exists();
    }

    private function hasOfficialBulletinForUnit(int $classId, object $unit): bool
    {
        return DB::table('gnu.bulletin as b')->join('gnu.inscription_classe as ic', 'ic.id', '=', 'b.inscription_classe_id')
            ->where('ic.classe_id', $classId)->where('b.courant', true)->whereIn('b.periode', ['S'.$unit->numero_semestre, 'ANNUELLE'])->exists();
    }

    /** @return array<int, int> */
    private function departmentIds(Request $request): array
    {
        if ($this->isPublicationAdministrator($request)) {
            DB::transaction(function () use ($request): void {
                $this->setAuditContext($request, 'Initialisation du périmètre administrateur système');
                DB::table('gnu.agent_administrateur_systeme')->insertOrIgnore([
                    'agent_id' => $request->user()->id,
                    'created_at' => now(),
                ]);
            });

            return DB::table('gnu.departement')->orderBy('id')->pluck('id')->map(static fn (mixed $id): int => (int) $id)->all();
        }

        return $this->scope->departmentIds((int) $request->user()->id);
    }

    private function isPublicationAdministrator(Request $request): bool
    {
        return in_array(mb_strtolower(trim((string) $request->user()->login)), config('academic.publication_admin_logins', []), true);
    }

    /** @return array<string, mixed> */
    private function officialPublicationRules(): array
    {
        return [
            'version_moteur' => 'GNU-1.6',
            'version_bareme' => 'GNU-MGP-100-V1',
            'echelle_note' => (float) config('academic.mark_scale', 20),
            'seuil_acquisition_sur_20' => (float) config('academic.passing_mark', 10),
            'arrondi_final_decimales' => (int) config('academic.mark_rounding_decimals', 2),
            'profils_ponderation_ec' => [
                ['CC' => 30, 'SN' => 70],
                ['CC' => 20, 'TPE' => 20, 'SN' => 60],
                ['CC' => 20, 'TP' => 30, 'SN' => 50],
            ],
            'bareme_points_qualite_sur_100' => [
                ['minimum' => 80, 'grade' => 'A', 'points' => 4.00],
                ['minimum' => 75, 'grade' => 'A-', 'points' => 3.70],
                ['minimum' => 70, 'grade' => 'B+', 'points' => 3.30],
                ['minimum' => 65, 'grade' => 'B', 'points' => 3.00],
                ['minimum' => 60, 'grade' => 'B-', 'points' => 2.70],
                ['minimum' => 55, 'grade' => 'C+', 'points' => 2.30],
                ['minimum' => 50, 'grade' => 'C', 'points' => 2.00],
                ['minimum' => 45, 'grade' => 'C-', 'points' => 1.70],
                ['minimum' => 40, 'grade' => 'D+', 'points' => 1.30],
                ['minimum' => 35, 'grade' => 'D', 'points' => 1.00],
                ['minimum' => 30, 'grade' => 'E', 'points' => 0.00],
                ['minimum' => 0, 'grade' => 'F', 'points' => 0.00],
            ],
            'admission_annuelle' => [
                'mgp_minimum' => (float) config('academic.admission_minimum_mgp', 2),
                'minimum_ue_sur_100' => (float) config('academic.admission_minimum_ue', 35),
                'elimination_ec' => true,
            ],
            'rattrapage' => [
                'minimum_sur_20' => (float) config('academic.retake_minimum_mark', 0),
                'maximum_sur_20_exclus' => (float) config('academic.retake_maximum_exclusive', 10),
                'seuil_rattrapage_obligatoire_sur_20' => (float) config('academic.retake_voluntary_mark', 7.5),
                'nombre_maximum_sessions' => (int) config('academic.retake_max_sessions', 1),
            ],
        ];
    }

    /** @param array<int, int> $departments */
    private function classesQuery(array $departments): Builder
    {
        return DB::table('gnu.classe as c')
            ->join('gnu.niveau as n', 'n.id', '=', 'c.niveau_id')
            ->join('gnu.filiere as f', 'f.id', '=', 'n.filiere_id')
            ->join('gnu.departement as d', 'd.id', '=', 'f.departement_id')
            ->join('gnu.faculte as fac', 'fac.id', '=', 'd.faculte_id')
            ->join('gnu.universite as un', 'un.id', '=', 'fac.universite_id')
            ->join('gnu.annee_academique as an', 'an.id', '=', 'c.annee_id')
            ->whereIn('f.departement_id', $departments);
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
