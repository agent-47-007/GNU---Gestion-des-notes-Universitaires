<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class AcademicReferenceController extends Controller
{
    public function years(): JsonResponse
    {
        return response()->json(['data' => DB::table('gnu.annee_academique')
            ->select(['id', 'libelle', 'date_debut', 'date_fin'])
            ->orderByDesc('date_debut')->get()]);
    }

    public function filieres(): JsonResponse
    {
        return response()->json(['data' => DB::table('gnu.filiere')
            ->select(['id', 'code_f', 'nom_f', 'departement_id'])
            ->orderBy('code_f')->get()]);
    }

    public function specialites(Request $request): JsonResponse
    {
        $query = DB::table('gnu.specialite as s')
            ->join('gnu.filiere as f', 'f.id', '=', 's.filiere_id')
            ->select(['s.id', 's.code_specialite', 's.libelle_specialite', 's.filiere_id', 'f.code_f'])
            ->orderBy('s.code_specialite');
        if ($request->filled('filiere_id')) {
            $query->where('s.filiere_id', $request->integer('filiere_id'));
        }

        return response()->json(['data' => $query->get()]);
    }

    public function niveaux(Request $request): JsonResponse
    {
        $query = DB::table('gnu.niveau as n')
            ->join('gnu.filiere as f', 'f.id', '=', 'n.filiere_id')
            ->select(['n.id', 'n.code_niv', 'n.libelle_niv', 'n.filiere_id', 'f.code_f', 'n.specialite_id'])
            ->orderBy('n.code_niv')->orderBy('n.id');
        if ($request->filled('filiere_id')) {
            $query->where('n.filiere_id', $request->integer('filiere_id'));
        }
        if ($request->filled('specialite_id')) {
            $query->where('n.specialite_id', $request->integer('specialite_id'));
        }

        return response()->json(['data' => $query->get()]);
    }

    public function semesters(): JsonResponse
    {
        return response()->json(['data' => DB::table('gnu.ue')
            ->select('numero_semestre')->distinct()->orderBy('numero_semestre')->get()
            ->map(fn ($row): array => ['numero' => $row->numero_semestre,
                'libelle' => 'Semestre '.$row->numero_semestre])]);
    }

    public function classes(Request $request): JsonResponse
    {
        $query = DB::table('gnu.classe as c')
            ->join('gnu.niveau as n', 'n.id', '=', 'c.niveau_id')
            ->join('gnu.filiere as f', 'f.id', '=', 'n.filiere_id')
            ->join('gnu.annee_academique as a', 'a.id', '=', 'c.annee_id')
            ->select(['c.id', 'c.code_classe', 'c.niveau_id', 'n.code_niv', 'f.code_f', 'c.annee_id', 'a.libelle', 'c.version_programme'])
            ->orderByDesc('a.date_debut')->orderBy('c.code_classe');
        foreach (['annee_id', 'niveau_id'] as $field) {
            if ($request->filled($field)) {
                $query->where('c.'.$field, $request->integer($field));
            }
        }

        return response()->json(['data' => $query->paginate(min($request->integer('per_page', 25), 100))]);
    }

    public function ues(Request $request): JsonResponse
    {
        $query = DB::table('gnu.ue as u')
            ->join('gnu.niveau as n', 'n.id', '=', 'u.niveau_id')
            ->join('gnu.filiere as f', 'f.id', '=', 'n.filiere_id')
            ->select(['u.id', 'u.code_ue as code', 'u.intitule_ue as intitule', 'u.niveau_id', 'n.code_niv', 'f.code_f', 'u.version_programme', 'u.numero_semestre as semestre', 'u.categorie_ue as categorie', 'u.credit_ue as credits', 'u.statut_catalogue as statut'])
            ->orderBy('n.code_niv')->orderBy('u.numero_semestre')->orderBy('u.code_ue');
        if ($request->filled('niveau_id')) {
            $query->where('u.niveau_id', $request->integer('niveau_id'));
        }
        if ($request->filled('semestre')) {
            $query->where('u.numero_semestre', $request->integer('semestre'));
        }
        if ($request->filled('statut')) {
            $query->where('u.statut_catalogue', $request->string('statut')->toString());
        }

        return response()->json(['data' => $query->paginate(min($request->integer('per_page', 25), 100))]);
    }

    public function ecs(Request $request): JsonResponse
    {
        $query = DB::table('gnu.matiere as m')
            ->join('gnu.ue as u', 'u.id', '=', 'm.ue_id')
            ->select(['m.id', 'm.code_m as code', 'm.intitule_matiere as intitule', 'm.ue_id', 'u.code_ue', 'm.rang_ec as rang', 'm.credit_matiere as credits'])
            ->orderBy('u.code_ue')->orderBy('m.rang_ec');
        if ($request->filled('ue_id')) {
            $query->where('m.ue_id', $request->integer('ue_id'));
        }

        return response()->json(['data' => $query->paginate(min($request->integer('per_page', 25), 100))]);
    }
}
