<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class PublicDirectoryController extends Controller
{
    private const COLUMNS = ['id', 'source_key', 'nom', 'categorie', 'region', 'ville', 'site_web', 'source_url', 'source_liste_url', 'source_date', 'consulte_le', 'verification', 'universite_id'];

    public function index(Request $request): JsonResponse
    {
        $data = $request->validate([
            'q' => ['nullable', 'string', 'max:150'], 'region' => ['nullable', 'string', 'max:80'],
            'categorie' => ['nullable', Rule::in(['UNIVERSITE_PUBLIQUE', 'IPES', 'INSTITUTION_PRIVEE', 'INTERNATIONAL'])],
            'page' => ['sometimes', 'integer', 'min:1'], 'per_page' => ['sometimes', 'integer', 'min:1', 'max:48'],
        ]);
        $query = DB::table('gnu.annuaire_institution');
        if (! empty($data['q'])) {
            $term = '%'.str_replace(['\\', '%', '_'], ['\\\\', '\\%', '\\_'], Str::lower(Str::ascii(trim($data['q'])))).'%';
            $query->where('recherche', 'like', $term);
        }
        foreach (['region', 'categorie'] as $filter) {
            if (! empty($data[$filter])) {
                $query->where($filter, $data[$filter]);
            }
        }
        $page = $query->orderBy('nom')->paginate($data['per_page'] ?? 18, self::COLUMNS);
        $metadata = DB::table('gnu.annuaire_metadata')->where('cle', 'sources')->value('contenu');

        return response()->json([
            'data' => $page->items(),
            'pagination' => ['page' => $page->currentPage(), 'pages' => $page->lastPage(), 'total' => $page->total()],
            'regions' => DB::table('gnu.annuaire_institution')->whereNotNull('region')->distinct()->orderBy('region')->pluck('region'),
            'statistiques' => DB::table('gnu.annuaire_institution')->selectRaw('categorie, count(*) AS nombre')->groupBy('categorie')->get(),
            'sources' => $metadata === null ? null : json_decode($metadata, true),
        ]);
    }

    public function show(int $institution): JsonResponse
    {
        $row = DB::table('gnu.annuaire_institution')->where('id', $institution)->first(self::COLUMNS);
        abort_if($row === null, 404);
        $faculties = collect();
        if ($row->universite_id !== null) {
            $faculties = DB::table('gnu.faculte')->where('universite_id', $row->universite_id)->orderBy('nom_fac')->get(['id', 'code_fac', 'nom_fac']);
            $departments = DB::table('gnu.departement')->whereIn('faculte_id', $faculties->pluck('id'))->orderBy('nom_depart')->get(['id', 'faculte_id', 'code_de', 'nom_depart']);
            $programs = DB::table('gnu.filiere')->whereIn('departement_id', $departments->pluck('id'))->orderBy('nom_f')->get(['id', 'departement_id', 'code_f', 'nom_f']);
            $levels = DB::table('gnu.niveau')->whereIn('filiere_id', $programs->pluck('id'))->orderBy('code_niv')->get(['id', 'filiere_id', 'code_niv', 'libelle_niv', 'cycle_niv']);
            $sources = DB::table('gnu.annuaire_structure_source')->where(function ($query) use ($faculties, $departments, $programs): void {
                $query->where(fn ($q) => $q->where('objet_type', 'faculte')->whereIn('objet_id', $faculties->pluck('id')))
                    ->orWhere(fn ($q) => $q->where('objet_type', 'departement')->whereIn('objet_id', $departments->pluck('id')))
                    ->orWhere(fn ($q) => $q->where('objet_type', 'filiere')->whereIn('objet_id', $programs->pluck('id')));
            })->get(['objet_type', 'objet_id', 'source_url', 'consulte_le', 'source_date', 'annee_source', 'details']);
            foreach ($sources as $source) {
                $source->details = json_decode($source->details, true);
            }
            foreach ($programs as $program) {
                $program->niveaux = $levels->where('filiere_id', $program->id)->values();
                $program->sources = $sources->where('objet_type', 'filiere')->where('objet_id', $program->id)->values();
            }
            foreach ($departments as $department) {
                $department->filieres = $programs->where('departement_id', $department->id)->values();
                $department->sources = $sources->where('objet_type', 'departement')->where('objet_id', $department->id)->values();
            }
            foreach ($faculties as $faculty) {
                $faculty->departements = $departments->where('faculte_id', $faculty->id)->values();
                $faculty->sources = $sources->where('objet_type', 'faculte')->where('objet_id', $faculty->id)->values();
            }
        }

        return response()->json(['data' => ['institution' => $row, 'etablissements' => $faculties,
            'information' => 'Les sources et durées sont conservées. Une consultation en 2026 ne confirme pas à elle seule l’ouverture en 2026-2027. Les formations sans département publié restent présentées au niveau de leur établissement.']]);
    }
}
