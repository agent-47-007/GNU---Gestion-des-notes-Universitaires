<?php

use App\Http\Controllers\AccountController;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\ProfileController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->name('api.v1.')->group(function (): void {
    Route::post('auth/login', [AuthController::class, 'login'])->middleware('throttle:login')->name('login');

    Route::middleware(['auth:sanctum', 'account.active', 'throttle:api'])->group(function (): void {
        Route::get('auth/me', [ProfileController::class, 'show'])->name('me');
        Route::post('auth/logout', [AuthController::class, 'logout'])->name('logout');
        Route::post('auth/logout-all', [AuthController::class, 'logoutAll'])->name('logout-all');
        Route::put('auth/password', [AuthController::class, 'password'])->middleware('throttle:password')->name('password');

        foreach (['etudiant' => 'ETUDIANT', 'enseignant' => 'ENSEIGNANT', 'agent' => 'AGENT'] as $path => $role) {
            Route::get('profil/'.$path, [ProfileController::class, 'show'])->middleware('role:'.$role)->name('profil.'.$path);
        }

        Route::middleware('role:AGENT')->group(function (): void {
            Route::apiResource('comptes', AccountController::class)->parameters(['comptes' => 'compte'])->only(['index', 'store', 'show', 'update']);
        });
    });
});
