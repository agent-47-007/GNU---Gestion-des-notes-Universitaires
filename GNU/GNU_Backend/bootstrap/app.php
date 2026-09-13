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
            Log::error('Erreur PostgreSQL', ['sqlstate' => $e->errorInfo[0] ?? $e->getCode()]);

            return false;
        });
        $exceptions->render(function (QueryException $e, Request $request) {
            if (! $request->is('api/*')) {
                return null;
            }

            return match ($e->errorInfo[0] ?? $e->getCode()) {
                '23505' => response()->json(['message' => 'Un identifiant est déjà utilisé.'], 409),
                '23514', '23503' => response()->json(['message' => 'Les données ne respectent pas les règles du dossier.'], 422),
                default => response()->json(['message' => 'Le service de données est indisponible.'], 503),
            };
        });
    })->create();
