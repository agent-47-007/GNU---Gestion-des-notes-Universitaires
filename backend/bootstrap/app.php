<?php

use App\Http\Middleware\EnsureAccountIsActive;
use App\Http\Middleware\EnsureRole;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->alias(['account.active' => EnsureAccountIsActive::class, 'role' => EnsureRole::class]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(fn (Request $request) => $request->is('api/*') || $request->expectsJson());
        $exceptions->dontFlash(['current_password', 'password', 'password_confirmation', 'mot_de_passe_hash']);
        $exceptions->report(function (QueryException $e): bool {
            Log::error('Erreur PostgreSQL', [
                'sqlstate' => $e->errorInfo[0] ?? $e->getCode(),
                'detail' => $e->errorInfo[2] ?? 'Détail PostgreSQL indisponible.',
            ]);

            return false;
        });
        $exceptions->render(function (QueryException $e, Request $request) {
            if (! $request->is('api/*')) {
                return null;
            }

            return match ($e->errorInfo[0] ?? $e->getCode()) {
                '23505' => response()->json([
                    'message' => str_contains($e->errorInfo[2] ?? '', 'uq_affectation_active')
                        ? 'Cet EC possède déjà un enseignant actif pour cette classe. Désactivez l’affectation actuelle avant de la remplacer.'
                        : 'Un identifiant unique existe déjà. Vérifiez qu’il n’y a pas de doublon puis réessayez.',
                ], 409),
                '23514' => response()->json([
                    'message' => str_contains($e->errorInfo[2] ?? '', 'Évaluation non réalisée')
                        ? 'La base doit être mise à jour pour permettre la saisie préparatoire des notes. Appliquez les migrations GNU puis réessayez.'
                        : 'Les données ne respectent pas les règles du dossier.',
                ], 422),
                '23503' => response()->json(['message' => 'Les données ne respectent pas les règles du dossier.'], 422),
                '23502' => response()->json(['message' => 'Une donnée obligatoire manque dans cet enregistrement. Vérifiez les champs requis et les migrations de la base.'], 422),
                '42P01', '42703' => response()->json(['message' => 'Le schéma PostgreSQL ne correspond pas à la version de l’application. Appliquez les migrations GNU puis réessayez.'], 503),
                '42501' => response()->json(['message' => 'Droits PostgreSQL insuffisants pour cette opération. Appliquez les migrations de droits GNU puis réessayez.'], 503),
                '08000', '08001', '08003', '08004', '08006', '08007', '08P01' => response()->json(['message' => 'PostgreSQL est inaccessible. Vérifiez que le service est démarré et que DB_HOST / DB_PORT sont corrects.'], 503),
                default => response()->json(['message' => 'Le service de données est indisponible.'], 503),
            };
        });
    })->create();
