<?php

namespace App\Http\Controllers;

use App\Http\Requests\ChangePasswordRequest;
use App\Http\Requests\LoginRequest;
use App\Http\Resources\UtilisateurResource;
use App\Models\Utilisateur;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    public function login(LoginRequest $request): JsonResponse
    {
        $data = $request->validated();

        return DB::transaction(function () use ($data, $request): JsonResponse {
            $user = Utilisateur::query()->whereRaw('lower(login) = lower(?)', [$data['login']])->lockForUpdate()->first();
            $hash = $user?->mot_de_passe_hash ?? config('auth.dummy_password_hash');
            $valid = Hash::check($data['password'], $hash);
            abort_unless($valid && $user && $user->actif && $user->hasCompleteProfile(), 401, 'Identifiants invalides.');

            if (Hash::needsRehash($hash)) {
                DB::select("SELECT set_config('gnu.acteur_id', ?, true), set_config('gnu.motif', ?, true)", [(string) $user->id, 'Mise à jour du hachage à la connexion']);
                $user->update(['mot_de_passe_hash' => Hash::make($data['password'])]);
            }

            $expiresAt = now()->addMinutes((int) config('sanctum.expiration'));
            $token = $user->createToken($data['device_name'], ['*'], $expiresAt);

            return response()->json([
                'token' => $token->plainTextToken,
                'token_type' => 'Bearer',
                'expires_at' => $expiresAt->toIso8601String(),
                'utilisateur' => (new UtilisateurResource($user))->resolve($request),
            ])->header('Cache-Control', 'no-store');
        });
    }

    public function logout(Request $request): Response
    {
        $request->user()->currentAccessToken()->delete();

        return response()->noContent();
    }

    public function logoutAll(Request $request): Response
    {
        DB::transaction(function () use ($request): void {
            $user = Utilisateur::query()->lockForUpdate()->findOrFail($request->user()->id);
            $user->tokens()->delete();
        });

        return response()->noContent();
    }

    public function password(ChangePasswordRequest $request): Response
    {
        $data = $request->validated();
        DB::transaction(function () use ($request, $data): void {
            $user = Utilisateur::query()->lockForUpdate()->findOrFail($request->user()->id);
            abort_unless($user->actif, 403, 'Compte indisponible.');
            if (! Hash::check($data['current_password'], $user->mot_de_passe_hash)) {
                throw ValidationException::withMessages(['current_password' => 'Le mot de passe actuel est incorrect.']);
            }
            DB::select("SELECT set_config('gnu.acteur_id', ?, true), set_config('gnu.motif', ?, true)", [(string) $user->id, 'Changement du mot de passe par son titulaire']);
            $user->update(['mot_de_passe_hash' => Hash::make($data['password'])]);
            $user->tokens()->delete();
        });

        return response()->noContent();
    }
}
