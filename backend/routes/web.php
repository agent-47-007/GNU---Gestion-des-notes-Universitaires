<?php

use App\Http\Controllers\LocalTestAccountController;
use Illuminate\Support\Facades\Route;

// The application interface is delivered by Flutter. Legacy mock views remain
// in the repository for reference but are intentionally not exposed as routes.
Route::get('/', fn () => response('API GNU prête. Ouvrez le portail Flutter Web sur http://127.0.0.1:8780.'));
Route::get('/local-test-accounts', [LocalTestAccountController::class, 'index'])->name('local-test-accounts.index');
Route::post('/local-test-accounts', [LocalTestAccountController::class, 'store'])->name('local-test-accounts.store');
