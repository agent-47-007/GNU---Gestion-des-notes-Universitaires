<?php

use App\Http\Controllers\AcademicReferenceController;
use App\Http\Controllers\AgentPortalController;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\ProfileController;
use App\Http\Controllers\StudentPortalController;
use App\Http\Controllers\TeacherPortalController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->name('api.v1.')->group(function (): void {
    Route::post('auth/login', [AuthController::class, 'login'])->middleware('throttle:login')->name('login');
    Route::middleware(['auth:sanctum', 'account.active', 'throttle:api'])->group(function (): void {
        Route::get('auth/me', [ProfileController::class, 'show'])->name('me');
        Route::post('auth/logout', [AuthController::class, 'logout'])->name('logout');
        Route::post('auth/logout-all', [AuthController::class, 'logoutAll'])->name('logout-all');
        Route::put('auth/password', [AuthController::class, 'password'])->middleware('throttle:password')->name('password');

        Route::prefix('referentiels')->name('referentiels.')->group(function (): void {
            Route::get('annees-academiques', [AcademicReferenceController::class, 'years'])->name('years');
            Route::get('filieres', [AcademicReferenceController::class, 'filieres'])->name('filieres');
            Route::get('specialites', [AcademicReferenceController::class, 'specialites'])->name('specialites');
            Route::get('niveaux', [AcademicReferenceController::class, 'niveaux'])->name('niveaux');
            Route::get('semestres', [AcademicReferenceController::class, 'semesters'])->name('semesters');
            Route::get('classes', [AcademicReferenceController::class, 'classes'])->name('classes');
            Route::get('ues', [AcademicReferenceController::class, 'ues'])->name('ues');
            Route::get('ecs', [AcademicReferenceController::class, 'ecs'])->name('ecs');
        });

        foreach (['etudiant' => 'ETUDIANT', 'enseignant' => 'ENSEIGNANT', 'agent' => 'AGENT'] as $path => $role) {
            Route::get('profil/'.$path, [ProfileController::class, 'show'])->middleware('role:'.$role)->name('profil.'.$path);
            Route::put('profil/'.$path, [ProfileController::class, 'updateSelf'])->middleware('role:'.$role)->name('profil.'.$path.'.update');
        }

        Route::middleware('role:ETUDIANT')->prefix('etudiant')->name('etudiant.')->group(function (): void {
            Route::get('inscriptions', [StudentPortalController::class, 'enrollment'])->name('inscriptions.index');
            Route::put('inscriptions', [StudentPortalController::class, 'saveEnrollment'])->name('inscriptions.save');
            Route::post('inscriptions/soumettre', [StudentPortalController::class, 'submitEnrollment'])->name('inscriptions.submit');
            Route::get('fiche-academique', [StudentPortalController::class, 'academicSheet'])->name('fiche-academique.show');
            Route::post('fiche-academique', [StudentPortalController::class, 'storeAcademicSheet'])->name('fiche-academique.store');
            Route::get('fiche-academique/fichier', [StudentPortalController::class, 'downloadAcademicSheet'])->name('fiche-academique.download');
            Route::get('inscriptions/{inscriptionClasse}/fiche-academique', [StudentPortalController::class, 'sharedAcademicSheet'])->name('inscriptions.fiche-academique');
            Route::get('resultats', [StudentPortalController::class, 'results'])->name('resultats');
            Route::get('resultats/provisoires', [StudentPortalController::class, 'provisionalResults'])->name('resultats.provisoires');
            Route::get('evaluations-manquantes', [StudentPortalController::class, 'missingEvaluations'])->name('evaluations.missing');
            Route::get('requetes', [StudentPortalController::class, 'requests'])->name('requetes.index');
            Route::post('requetes', [StudentPortalController::class, 'createRequest'])->name('requetes.store');
            Route::get('requetes/{requete}/justificatif', [StudentPortalController::class, 'downloadJustificatif'])->name('requetes.justificatif');
            Route::get('rattrapages', [StudentPortalController::class, 'retakes'])->name('rattrapages');
            Route::post('rattrapages/candidatures', [StudentPortalController::class, 'applyForRetake'])->name('rattrapages.candidatures.store');
            Route::get('notifications', [StudentPortalController::class, 'notifications'])->name('notifications.index');
            Route::patch('notifications/{notification}/lue', [StudentPortalController::class, 'markNotificationRead'])->name('notifications.read');
        });

        Route::middleware('role:AGENT')->prefix('agent')->name('agent.')->group(function (): void {
            Route::get('dashboard', [AgentPortalController::class, 'dashboard'])->name('dashboard');
            Route::get('classes', [AgentPortalController::class, 'classes'])->name('classes.index');
            Route::post('classes', [AgentPortalController::class, 'storeClass'])->name('classes.store');
            Route::get('niveaux', [AgentPortalController::class, 'levels'])->name('niveaux.index');
            Route::get('catalogue', [AgentPortalController::class, 'catalog'])->name('catalogue');
            Route::get('structure', [AgentPortalController::class, 'academicStructure'])->name('structure.index');
            Route::post('structure/universites', [AgentPortalController::class, 'storeUniversity'])->name('structure.universites.store');
            Route::patch('structure/universites/{universite}', [AgentPortalController::class, 'updateUniversity'])->name('structure.universites.update');
            Route::post('structure/facultes', [AgentPortalController::class, 'storeFaculty'])->name('structure.facultes.store');
            Route::patch('structure/facultes/{faculte}', [AgentPortalController::class, 'updateFaculty'])->name('structure.facultes.update');
            Route::post('structure/departements', [AgentPortalController::class, 'storeDepartment'])->name('structure.departements.store');
            Route::patch('structure/departements/{departement}', [AgentPortalController::class, 'updateDepartment'])->name('structure.departements.update');
            Route::post('structure/filieres', [AgentPortalController::class, 'storeTrack'])->name('structure.filieres.store');
            Route::patch('structure/filieres/{filiere}', [AgentPortalController::class, 'updateTrack'])->name('structure.filieres.update');
            Route::post('ues', [AgentPortalController::class, 'storeUnit'])->name('ues.store');
            Route::post('ues/{ue}/elements', [AgentPortalController::class, 'storeElement'])->name('ues.elements.store');
            Route::patch('ues/{ue}/statut', [AgentPortalController::class, 'setUnitStatus'])->name('ues.status');
            Route::put('ues/{ue}/profil-evaluation', [AgentPortalController::class, 'setUnitEvaluationProfile'])->name('ues.evaluation-profile');
            Route::get('comptes', [AgentPortalController::class, 'accounts'])->name('comptes.index');
            Route::patch('comptes/{utilisateur}', [AgentPortalController::class, 'updateAccount'])->name('comptes.update');
            Route::patch('comptes/{utilisateur}/statut', [AgentPortalController::class, 'setAccountStatus'])->name('comptes.status');
            Route::post('affectations', [AgentPortalController::class, 'storeAssignment'])->name('affectations.store');
            Route::get('affectations', [AgentPortalController::class, 'assignments'])->name('affectations.index');
            Route::patch('affectations/{affectation}', [AgentPortalController::class, 'setAssignmentStatus'])->name('affectations.status');
            Route::get('inscriptions', [AgentPortalController::class, 'enrollments'])->name('inscriptions.index');
            Route::patch('inscriptions/{inscriptionSemestre}', [AgentPortalController::class, 'reviewEnrollment'])->name('inscriptions.review');
            Route::get('inscriptions/{inscriptionClasse}/fiche-academique', [AgentPortalController::class, 'downloadAcademicSheet'])->name('inscriptions.fiche-academique');
            Route::get('requetes', [AgentPortalController::class, 'requests'])->name('requetes.index');
            Route::patch('requetes/{requete}/affectation', [AgentPortalController::class, 'routeRequestToTeacher'])->name('requetes.route');
            Route::get('notes/transmissions', [AgentPortalController::class, 'gradeTransmissions'])->name('notes.transmissions');
            Route::put('notes/transmissions/{transmission}/numerisation', [AgentPortalController::class, 'digitizeGradeTransmission'])->name('notes.transmissions.digitize');
            Route::patch('notes/transmissions/{transmission}/retour', [AgentPortalController::class, 'returnGradeTransmission'])->name('notes.transmissions.return');
            Route::get('classes/{classe}/apercu-bulletins', [AgentPortalController::class, 'bulletinPreview'])->name('bulletins.preview');
            Route::post('classes/{classe}/publications', [AgentPortalController::class, 'publish'])->name('publications.store');
            Route::get('publication/regles', [AgentPortalController::class, 'publicationRules'])->name('publication.rules');
            Route::post('publication/regles/approuver', [AgentPortalController::class, 'approvePublicationRules'])->name('publication.rules.approve');
            Route::put('publication/habilitations/{utilisateur}', [AgentPortalController::class, 'setPublicationAuthorization'])->name('publication.authorization');
            Route::get('audit', [AgentPortalController::class, 'audit'])->name('audit.index');
            Route::get('rattrapages/sessions', [AgentPortalController::class, 'sessions'])->name('rattrapages.sessions.index');
            Route::get('rattrapages/opportunites', [AgentPortalController::class, 'retakeOpportunities'])->name('rattrapages.opportunites');
            Route::post('rattrapages/sessions', [AgentPortalController::class, 'storeSession'])->name('rattrapages.sessions.store');
            Route::patch('rattrapages/sessions/{session}', [AgentPortalController::class, 'setSessionStatus'])->name('rattrapages.sessions.status');
        });

        Route::middleware('role:ENSEIGNANT')->prefix('enseignant')->name('enseignant.')->group(function (): void {
            Route::get('affectations', [TeacherPortalController::class, 'assignments'])->name('affectations.index');
            Route::get('affectations/{affectation}/plan-evaluation', [TeacherPortalController::class, 'evaluationPlan'])->name('affectations.plan');
            Route::put('affectations/{affectation}/plan-evaluation', [TeacherPortalController::class, 'saveEvaluationPlan'])->name('affectations.plan.save');
            Route::get('affectations/{affectation}/carnet', [TeacherPortalController::class, 'gradebook'])->name('affectations.carnet');
            Route::get('affectations/{affectation}/inscriptions/{inscriptionClasse}/fiche-academique', [TeacherPortalController::class, 'downloadAcademicSheet'])->name('affectations.inscriptions.fiche-academique');
            Route::get('affectations/{affectation}/bulletins-provisoires', [TeacherPortalController::class, 'provisionalBulletins'])->name('affectations.bulletins.provisoires');
            Route::patch('affectations/{affectation}/evaluations/{evaluation}', [TeacherPortalController::class, 'updateEvaluationStatus'])->name('affectations.evaluations.status');
            Route::put('affectations/{affectation}/evaluations/{evaluation}/notes', [TeacherPortalController::class, 'saveGrades'])->name('affectations.notes.save');
            Route::put('affectations/{affectation}/notes-etudiant', [TeacherPortalController::class, 'saveStudentGrades'])->name('affectations.notes.student.save');
            Route::post('affectations/{affectation}/evaluations/{evaluation}/notes/transmettre', [TeacherPortalController::class, 'transmitGrades'])->name('affectations.notes.transmettre');
            Route::patch('transmissions-notes/{transmission}', [TeacherPortalController::class, 'decideTransmission'])->name('transmissions-notes.decide');
            Route::post('affectations/{affectation}/evaluations/{evaluation}/notes/importer', [TeacherPortalController::class, 'importGrades'])->name('affectations.notes.importer');
            Route::post('affectations/{affectation}/notes/importer-classe', [TeacherPortalController::class, 'previewGradebookImport'])->name('affectations.notes.importer-classe');
            Route::post('affectations/{affectation}/profil-evaluation/proposition', [TeacherPortalController::class, 'proposeEvaluationProfile'])->name('affectations.evaluation-profile.propose');
            Route::patch('affectations/{affectation}/notes/{note}/retrait', [TeacherPortalController::class, 'removeGrade'])->name('affectations.notes.retrait');
            Route::post('affectations/{affectation}/rattrapages/sessions', [TeacherPortalController::class, 'storeRetakeSession'])->name('affectations.rattrapages.sessions.store');
            Route::get('affectations/{affectation}/rattrapages', [TeacherPortalController::class, 'retakeCandidates'])->name('affectations.rattrapages.index');
            Route::post('affectations/{affectation}/rattrapages/sessions/{session}/evaluations', [TeacherPortalController::class, 'createRetakeEvaluations'])->name('affectations.rattrapages.evaluations.store');
            Route::put('affectations/{affectation}/rattrapages/evaluations/{evaluation}/notes', [TeacherPortalController::class, 'saveRetakeGrades'])->name('affectations.rattrapages.notes.save');
            Route::get('requetes', [TeacherPortalController::class, 'requests'])->name('requetes.index');
            Route::patch('requetes/{requete}', [TeacherPortalController::class, 'decideRequest'])->name('requetes.decide');
        });
    });
});
