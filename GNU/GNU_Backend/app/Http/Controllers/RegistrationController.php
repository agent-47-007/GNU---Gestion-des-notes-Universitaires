<?php

namespace App\Http\Controllers;

use App\Enums\Role;
use App\Http\Requests\RegisterStudentRequest;
use App\Http\Resources\UtilisateurResource;
use App\Models\Utilisateur;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

class RegistrationController extends Controller
{
    public function registerStudent(RegisterStudentRequest $request): JsonResponse
    {
        $data = $request->validated();

        return DB::transaction(function () use ($data, $request): JsonResponse {
            $user = Utilisateur::query()->create([
                'code_utilisateur' => 'ETU-'.$data['matricule'],
                'login' => $data['matricule'],
                'mot_de_passe_hash' => Hash::make($data['password']),
                'role' => Role::Etudiant->value,
                'actif' => true,
                'nom' => $data['nom'],
                'prenom' => $data['prenom'],
            ]);

            $user->etudiant()->create(['matricule' => $data['matricule']]);
            $expiresAt = now()->addMinutes((int) config('sanctum.expiration'));
            $token = $user->createToken('GNU Web', ['*'], $expiresAt);

            return response()->json([
                'token' => $token->plainTextToken,
                'token_type' => 'Bearer',
                'expires_at' => $expiresAt->toIso8601String(),
                'utilisateur' => (new UtilisateurResource($user))->resolve($request),
            ], 201)->header('Cache-Control', 'no-store');
        });
    }
}