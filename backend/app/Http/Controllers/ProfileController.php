<?php

namespace App\Http\Controllers;

use App\Http\Resources\UtilisateurResource;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class ProfileController extends Controller
{
    public function show(Request $request): UtilisateurResource
    {
        return new UtilisateurResource($request->user());
    }

    public function updateStudent(Request $request): UtilisateurResource
    {
        return $this->updateSelf($request);
    }

    public function updateSelf(Request $request): UtilisateurResource
    {
        $data = $request->validate([
            'nom' => ['sometimes', 'required', 'string', 'max:120'],
            'prenom' => ['sometimes', 'required', 'string', 'max:120'],
            'courriel' => ['sometimes', 'nullable', 'email:rfc', 'max:254'],
        ]);
        $email = isset($data['courriel']) ? strtolower(trim($data['courriel'])) : null;
        $duplicate = array_key_exists('courriel', $data) && $email !== null && DB::table('gnu.utilisateur')
            ->whereRaw('lower(courriel) = ?', [$email])
            ->where('id', '!=', $request->user()->id)->exists();
        if ($duplicate) {
            throw ValidationException::withMessages(['courriel' => ['Cette adresse courriel est déjà associée à un compte.']]);
        }

        DB::transaction(function () use ($request, $data, $email): void {
            DB::select("SELECT set_config('gnu.acteur_id', ?, true), set_config('gnu.motif', ?, true)", [(string) $request->user()->id, 'Mise à jour du profil par son titulaire']);
            $user = $request->user();
            foreach (['nom', 'prenom'] as $field) {
                if (array_key_exists($field, $data)) {
                    $user->{$field} = trim($data[$field]);
                }
            }
            if (array_key_exists('courriel', $data)) {
                $user->courriel = $email;
            }
            $user->save();
        });

        return new UtilisateurResource($request->user()->refresh());
    }
}
