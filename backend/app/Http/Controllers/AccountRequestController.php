<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;

class AccountRequestController extends Controller
{
    public function departments(): JsonResponse
    {
        $departments = DB::table('gnu.departement as d')
            ->join('gnu.faculte as f', 'f.id', '=', 'd.faculte_id')
            ->orderBy('f.nom_fac')->orderBy('d.nom_depart')
            ->get(['d.id', 'd.code_de', 'd.nom_depart', 'f.nom_fac', 'f.id as faculte_id']);
        $programs = DB::table('gnu.filiere as fi')->join('gnu.departement as d', 'd.id', '=', 'fi.departement_id')->orderBy('fi.nom_f')->get(['fi.id', 'fi.code_f', 'fi.nom_f', 'fi.departement_id']);
        $specialities = DB::table('gnu.specialite as s')->join('gnu.filiere as fi', 'fi.id', '=', 's.filiere_id')->where('s.actif', true)->orderBy('s.libelle_specialite')->get(['s.id', 's.code_specialite', 's.libelle_specialite', 's.filiere_id']);
        $years = DB::table('gnu.annee_academique as a')
            ->join('gnu.classe as c', 'c.annee_id', '=', 'a.id')
            ->select(['a.id', 'a.libelle', 'a.date_debut'])
            ->where('a.libelle', config('academic.active_year'))->distinct()->orderByDesc('a.date_debut')->get();
        $classes = DB::table('gnu.classe as c')
            ->join('gnu.niveau as n', 'n.id', '=', 'c.niveau_id')
            ->join('gnu.filiere as fi', 'fi.id', '=', 'n.filiere_id')
            ->join('gnu.departement as d', 'd.id', '=', 'fi.departement_id')
            ->join('gnu.annee_academique as a', 'a.id', '=', 'c.annee_id')
            ->leftJoin('gnu.specialite as sp', 'sp.id', '=', 'n.specialite_id')
            ->where('a.libelle', config('academic.active_year'))
            ->orderByDesc('a.date_debut')->orderBy('c.code_classe')
            ->get([
                'c.id', 'c.code_classe', 'c.annee_id', 'a.libelle as annee_academique',
                'c.niveau_id', 'n.code_niv', 'n.libelle_niv', 'n.specialite_id',
                'fi.id as filiere_id', 'fi.code_f', 'fi.nom_f', 'd.id as departement_id',
                'd.nom_depart', 'sp.libelle_specialite',
            ]);

        return response()->json(['data' => [
            'annee_active' => config('academic.active_year'),
            'etablissements' => DB::table('gnu.faculte')->orderBy('nom_fac')->get(['id', 'code_fac', 'nom_fac']),
            'departements' => $departments,
            'filieres' => $programs,
            'specialites' => $specialities,
            'annees' => $years,
            'classes' => $classes,
        ]]);
    }

    public function submit(Request $request): JsonResponse
    {
        $data = $request->validate([
            'role' => ['required', Rule::in(['ETUDIANT', 'ENSEIGNANT', 'AGENT'])],
            'login' => ['required', 'string', 'max:64', 'regex:/^[A-Za-z0-9._-]+$/'],
            'nom' => ['required', 'string', 'max:120'],
            'prenom' => ['required', 'string', 'max:120'],
            'courriel' => ['nullable', 'email:rfc', 'max:254'],
            'identifiant_profil' => ['required', 'string', 'max:59', 'regex:/^[A-Za-z0-9-]+$/'],
            // The PostgreSQL connection already searches the `gnu` schema.
            // `exists:gnu.table,id` makes Laravel treat `gnu` as a connection name.
            'departement_id' => ['required', 'integer', Rule::exists('departement', 'id')],
            'filiere_id' => ['nullable', 'integer', Rule::exists('filiere', 'id')],
            'specialite_id' => ['nullable', 'integer', Rule::exists('specialite', 'id')],
            'annee_id' => ['nullable', 'required_if:role,ETUDIANT', 'integer', Rule::exists('annee_academique', 'id')->where('libelle', config('academic.active_year'))],
            'classe_id' => ['nullable', 'required_if:role,ETUDIANT', 'integer', Rule::exists('classe', 'id')],
            'reference_identite' => ['required', 'string', 'min:4', 'max:160'],
            'password' => ['required', 'string', 'min:12', 'confirmed'],
        ], [
            'reference_identite.required' => 'Saisissez le numéro ou la référence de votre pièce d’identité.',
            'reference_identite.min' => 'La référence de la pièce d’identité doit contenir au moins 4 caractères.',
            'password.min' => 'Le mot de passe doit contenir au moins 12 caractères.',
            'password.confirmed' => 'Les deux mots de passe ne correspondent pas.',
        ]);

        if ($data['role'] === 'ETUDIANT') {
            $requestedClass = DB::table('gnu.classe as c')
                ->join('gnu.niveau as n', 'n.id', '=', 'c.niveau_id')
                ->join('gnu.filiere as fi', 'fi.id', '=', 'n.filiere_id')
                ->where('c.id', $data['classe_id'])
                ->first(['c.annee_id', 'fi.id as filiere_id', 'fi.departement_id', 'n.specialite_id']);
            abort_unless(
                $requestedClass !== null
                    && (int) $requestedClass->annee_id === (int) $data['annee_id']
                    && (int) $requestedClass->departement_id === (int) $data['departement_id'],
                422,
                'La classe choisie ne correspond pas au département et à l’année demandés.',
            );
            abort_if(
                ! empty($data['filiere_id']) && (int) $data['filiere_id'] !== (int) $requestedClass->filiere_id,
                422,
                'La classe choisie ne correspond pas à la filière demandée.',
            );
            abort_if(
                ! empty($data['specialite_id']) && (int) $data['specialite_id'] !== (int) ($requestedClass->specialite_id ?? 0),
                422,
                'La classe choisie ne correspond pas à la spécialité demandée.',
            );
            $data['filiere_id'] = (int) $requestedClass->filiere_id;
            $data['specialite_id'] = $requestedClass->specialite_id === null
                ? null
                : (int) $requestedClass->specialite_id;
        } else {
            if (! empty($data['filiere_id'])) {
                abort_unless(DB::table('gnu.filiere')->where('id', $data['filiere_id'])->where('departement_id', $data['departement_id'])->exists(), 422, 'La filière ne correspond pas au département sélectionné.');
            }
            if (! empty($data['specialite_id'])) {
                abort_unless(! empty($data['filiere_id']) && DB::table('gnu.specialite')->where('id', $data['specialite_id'])->where('filiere_id', $data['filiere_id'])->where('actif', true)->exists(), 422, 'L’option ne correspond pas à la filière sélectionnée.');
            }
            abort_unless(
                empty($data['annee_id']) && empty($data['classe_id']),
                422,
                'L’année et la classe ne sont demandées que pour une inscription étudiante.',
            );
        }

        $login = trim($data['login']);
        $profile = strtoupper(trim($data['identifiant_profil']));
        $profileCode = match ($data['role']) {
            'ETUDIANT' => 'ETU-'.$profile,
            'ENSEIGNANT' => 'ENS-'.$profile,
            'AGENT' => 'AGT-'.$profile,
        };
        abort_if(trim($data['nom']) === '' || trim($data['prenom']) === '', 422, 'Le nom et le prénom sont obligatoires.');
        abort_if(DB::table('gnu.utilisateur')->whereRaw('lower(login) = lower(?)', [$login])->exists(), 409, 'Cet identifiant est déjà utilisé.');
        abort_if(DB::table('gnu.demande_compte')->where('statut', 'EN_ATTENTE')->whereRaw('lower(login) = lower(?)', [$login])->exists(), 409, 'Une demande est déjà en attente pour cet identifiant.');
        abort_if(DB::table('gnu.utilisateur')->whereRaw('upper(code_utilisateur) = upper(?)', [$profileCode])->exists(), 409, 'Cet identifiant de profil est déjà utilisé.');
        $profileExists = match ($data['role']) {
            'ETUDIANT' => DB::table('gnu.etudiant')->whereRaw('upper(matricule) = upper(?)', [$profile])->exists(),
            'ENSEIGNANT' => DB::table('gnu.enseignant')->whereRaw('upper(eid) = upper(?)', [$profile])->exists(),
            default => false,
        };
        abort_if($profileExists, 409, 'Cet identifiant de profil est déjà utilisé.');
        abort_if(DB::table('gnu.demande_compte')->where('statut', 'EN_ATTENTE')->where('role', $data['role'])->whereRaw('upper(identifiant_profil) = ?', [$profile])->exists(), 409, 'Une demande est déjà en attente pour cet identifiant de profil.');

        $id = DB::table('gnu.demande_compte')->insertGetId([
            'role' => $data['role'],
            'login' => $login,
            'code_utilisateur' => $profileCode,
            'nom' => trim($data['nom']),
            'prenom' => trim($data['prenom']),
            'courriel' => isset($data['courriel']) ? mb_strtolower(trim($data['courriel'])) : null,
            'identifiant_profil' => $profile,
            'departement_id' => $data['departement_id'],
            'filiere_id' => $data['filiere_id'] ?? null,
            'specialite_id' => $data['specialite_id'] ?? null,
            'classe_id' => $data['classe_id'] ?? null,
            'reference_identite' => trim($data['reference_identite']),
            'mot_de_passe_hash' => Hash::make($data['password']),
            'created_at' => now(),
            'updated_at' => now(),
        ], 'id');

        return response()->json([
            'message' => 'Demande envoyée. Le compte sera activé après vérification par l’administration.',
            'data' => ['id' => $id, 'statut' => 'EN_ATTENTE'],
        ], 202)->header('Cache-Control', 'no-store');
    }
}
