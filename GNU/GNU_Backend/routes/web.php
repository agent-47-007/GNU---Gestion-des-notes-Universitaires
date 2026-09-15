<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\MaquetteController;
use App\Http\Controllers\RoleSpaceController;
use App\Http\Controllers\ProfilePageController;

Route::view('/', 'welcome')->name('home');
Route::view('/connexion', 'auth.login')->name('login');
Route::view('/inscription', 'auth.register')->name('register');
Route::view('/guide-lmd', 'guide.lmd')->name('guide.lmd');
Route::view('/support-registres', 'support.registres')->name('support.registres');
Route::view('/profil', 'profile')->name('profile');
Route::get('/etudiant', [RoleSpaceController::class, 'show'])->defaults('role', 'etudiant')->name('student.space');
Route::get('/enseignant', [RoleSpaceController::class, 'show'])->defaults('role', 'enseignant')->name('teacher.space');
Route::get('/agent', [RoleSpaceController::class, 'show'])->defaults('role', 'agent')->name('agent.space');
Route::get('/{role}/{page}', [ProfilePageController::class, 'show'])->whereIn('role', ['etudiant', 'enseignant', 'agent'])->name('profile.page');
Route::get('/maquettes', [MaquetteController::class, 'index'])->name('maquettes.index');
Route::get('/maquettes/{slug}', [MaquetteController::class, 'show'])->name('maquettes.show');
