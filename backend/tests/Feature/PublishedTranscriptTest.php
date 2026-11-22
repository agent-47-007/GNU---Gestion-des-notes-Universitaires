<?php

namespace Tests\Feature;

use App\Models\Enseignant;
use App\Models\Etudiant;
use App\Models\Utilisateur;
use App\Services\AgentDepartmentScope;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Symfony\Component\Process\Process;
use Tests\TestCase;

class PublishedTranscriptTest extends TestCase
{
    public function test_published_pdfs_match_their_registration_and_are_reused(): void
    {
        $this->connectIsolatedDatabase();
        Storage::fake('local');
        DB::beginTransaction();
        try {
            // CREATE SCHEMA intentionally fails if the database already contains GNU.
            DB::unprepared(file_get_contents(__DIR__.'/../Fixtures/transcript.sql'));
            foreach ([[101, 1, 'DEMO-A', 86.5], [102, 2, 'DEMO-B', 44.25]] as [$id, $registration, $matricule, $score]) {
                DB::table('gnu.bulletin')->insert([
                    'id' => $id, 'inscription_classe_id' => $registration, 'publication_id' => 1,
                    'periode' => 'S2', 'courant' => true, 'version_bulletin' => 1, 'mgp_s2' => 2.5, 'total_credits' => 6,
                    'contenu_fige' => json_encode(['inscription_classe_id' => $registration,
                        'identite' => ['matricule' => $matricule, 'nom' => 'Test', 'prenom' => $matricule],
                        'ues' => [['ue_id' => 1, 'code_ue' => 'INF200', 'arrondi' => $score, 'credit' => 6, 'semestre' => 2]],
                        'total_credits' => 6]),
                ]);
            }
            foreach ([[1, 101, 102, 'DEMO-A', 'DEMO-B', 86.5, '86,50'], [2, 102, 101, 'DEMO-B', 'DEMO-A', 44.25, '44,25']] as [$id, $own, $other, $matricule, $otherMatricule, $score, $printed]) {
                $user = new Utilisateur(['role' => 'ETUDIANT', 'actif' => true]);
                $user->id = $id;
                $user->setRelation('etudiant', new Etudiant);
                Sanctum::actingAs($user);
                $base = '/api/v1/etudiant/resultats';
                $this->getJson($base.'?periode=S2')->assertOk()->assertJsonCount(1, 'data')
                    ->assertJsonPath('data.0.matricule', $matricule)->assertJsonPath('data.0.contenu.ues.0.arrondi', $score);
                $this->getJson($base.'?periode=S1')->assertOk()->assertJsonCount(0, 'data');
                $this->getJson("$base/$other/document")->assertNotFound();
                $pdf = $this->get("$base/$own/document")->assertOk()->assertHeader('Content-Type', 'application/pdf')->getContent();
                $reader = new Process(['pdftotext', '-layout', '-', '-']);
                $reader->setInput($pdf)->mustRun();
                $this->assertStringContainsString($matricule, $reader->getOutput());
                $this->assertStringContainsString($printed, $reader->getOutput());
                $this->assertStringNotContainsString($otherMatricule, $reader->getOutput());
                $this->assertSame($pdf, $this->get("$base/$own/document")->assertOk()->getContent());
                $this->postJson("$base/$own/document")->assertStatus(405);
                DB::table('gnu.bulletin')->where('id', $own)->update(['courant' => false]);
                $this->getJson("$base/$own/document")->assertNotFound();
            }
            $this->assertSame(2, DB::table('gnu.document_bulletin')->count());
        } finally {
            DB::rollBack();
        }
    }

    public function test_teacher_marks_are_preserved_when_digitization_is_reviewed(): void
    {
        $this->connectIsolatedDatabase();
        DB::beginTransaction();
        try {
            DB::unprepared(file_get_contents(__DIR__.'/../Fixtures/transcript.sql'));
            DB::unprepared(file_get_contents(__DIR__.'/../Fixtures/teacher-grade-review.sql'));
            $teacher = new Utilisateur(['role' => 'ENSEIGNANT', 'actif' => true]);
            $teacher->id = 3;
            $teacher->setRelation('enseignant', new Enseignant);
            Sanctum::actingAs($teacher);
            $this->putJson('/api/v1/enseignant/affectations/1/evaluations/55/notes', ['notes' => [
                ['matricule' => 'DEMO-B', 'situation' => 'NUMERIQUE', 'valeur_note' => 0],
                ['matricule' => 'DEMO-A', 'situation' => 'NUMERIQUE', 'valeur_note' => 15.75],
            ]])->assertOk()->assertJsonPath('enregistrements', 2);
            DB::table('gnu.transmission_note')->insert(['id' => 8, 'evaluation_id' => 55, 'enseignant_id' => 1,
                'affectation_id' => 1, 'statut' => 'A_VERIFIER', 'version' => 1, 'traite_le' => now()->addMinute()]);
            DB::statement("INSERT INTO gnu.note_numerisee VALUES (8,55,21,13,'NUMERIQUE',1),(8,55,22,NULL,'ABSENTE',1)");
            $review = '/api/v1/enseignant/transmissions-notes/8';
            $this->patchJson($review, ['decision' => 'VERIFIER'])->assertConflict();
            $this->assertEquals(15.75, DB::table('gnu.note')->where('inscription_ue_id', 21)->value('valeur_note'));
            DB::table('gnu.note_numerisee')->where('inscription_ue_id', 21)->update(['valeur_note' => 15.750]);
            $this->patchJson($review, ['decision' => 'VERIFIER'])->assertConflict();
            $this->assertEquals(2, DB::table('gnu.note')->where('statut_note', 'BROUILLON')->count());
            DB::table('gnu.note_numerisee')->where('inscription_ue_id', 22)->update(['situation' => 'NUMERIQUE', 'valeur_note' => 0]);
            $this->patchJson($review, ['decision' => 'VERIFIER'])->assertOk();
            $validated = DB::table('gnu.note')->where('evaluation_id', 55)->where('statut_note', 'VALIDEE')
                ->pluck('valeur_note', 'inscription_ue_id')->all();
            $this->assertEquals([21 => 15.75, 22 => 0], $validated);
        } finally {
            DB::rollBack();
        }
    }

    public function test_account_choices_only_expose_the_active_year_and_keep_establishments(): void
    {
        $this->connectIsolatedDatabase();
        config(['academic.active_year' => '2026-2027']);
        DB::beginTransaction();
        try {
            DB::unprepared(file_get_contents(__DIR__.'/../Fixtures/transcript.sql'));
            DB::unprepared("ALTER TABLE gnu.faculte ADD code_fac text;
                ALTER TABLE gnu.departement ADD code_de text;
                ALTER TABLE gnu.filiere ADD code_f text;
                ALTER TABLE gnu.specialite ADD code_specialite text, ADD filiere_id int, ADD actif boolean;
                INSERT INTO gnu.annee_academique VALUES (2,'2026-2027','2026-10-01');
                INSERT INTO gnu.classe VALUES (2,'INF-L2-2026-2027',1,2);");
            $this->getJson('/api/v1/auth/demandes-compte/departements')->assertOk()
                ->assertJsonPath('data.annee_active', '2026-2027')
                ->assertJsonCount(1, 'data.annees')->assertJsonPath('data.annees.0.id', 2)
                ->assertJsonCount(1, 'data.classes')->assertJsonPath('data.classes.0.id', 2)
                ->assertJsonPath('data.departements.0.faculte_id', 1)
                ->assertJsonCount(1, 'data.etablissements');
            $scope = app(AgentDepartmentScope::class);
            $this->assertFalse($scope->hasClass([1], 1));
            $this->assertTrue($scope->hasClass([1], 2));
            $payload = ['role' => 'ETUDIANT', 'login' => 'new.student', 'nom' => 'Test', 'prenom' => 'Student',
                'identifiant_profil' => 'TEST2026', 'departement_id' => 1, 'annee_id' => 1, 'classe_id' => 1,
                'reference_identite' => 'TEST-ID', 'password' => 'Test-password-2026', 'password_confirmation' => 'Test-password-2026'];
            $this->postJson('/api/v1/auth/demandes-compte', $payload)->assertUnprocessable()->assertJsonValidationErrors('annee_id');
            $payload['annee_id'] = 2;
            $this->postJson('/api/v1/auth/demandes-compte', $payload)->assertUnprocessable();
        } finally {
            DB::rollBack();
        }
    }

    public function test_catalog_initialization_is_repeatable_and_preserves_existing_classes(): void
    {
        $this->connectIsolatedDatabase();
        DB::beginTransaction();
        try {
            DB::unprepared(file_get_contents(__DIR__.'/../Fixtures/transcript.sql'));
            DB::unprepared("ALTER TABLE gnu.universite ADD code_univ text;
                UPDATE gnu.universite SET code_univ='UY1';
                ALTER TABLE gnu.faculte ADD code_fac text;
                UPDATE gnu.faculte SET code_fac='FS';
                ALTER TABLE gnu.departement ADD code_de text;
                UPDATE gnu.departement SET code_de='INFO';
                ALTER TABLE gnu.filiere ADD code_f text;
                ALTER TABLE gnu.annee_academique ADD date_fin date;
                ALTER TABLE gnu.classe ADD version_programme int DEFAULT 1, ADD specialite_id int;
                ALTER TABLE gnu.faculte ALTER id SET NOT NULL;
                ALTER TABLE gnu.faculte ALTER id ADD GENERATED BY DEFAULT AS IDENTITY (START WITH 100);
                ALTER TABLE gnu.departement ALTER id SET NOT NULL;
                ALTER TABLE gnu.departement ALTER id ADD GENERATED BY DEFAULT AS IDENTITY (START WITH 100);
                ALTER TABLE gnu.filiere ALTER id SET NOT NULL;
                ALTER TABLE gnu.filiere ALTER id ADD GENERATED BY DEFAULT AS IDENTITY (START WITH 100);
                ALTER TABLE gnu.annee_academique ALTER id SET NOT NULL;
                ALTER TABLE gnu.annee_academique ALTER id ADD GENERATED BY DEFAULT AS IDENTITY (START WITH 100);
                ALTER TABLE gnu.classe ALTER id SET NOT NULL;
                ALTER TABLE gnu.classe ALTER id ADD GENERATED BY DEFAULT AS IDENTITY (START WITH 100);
                CREATE TABLE gnu.profil_evaluation_ue (ue_id int, configure_par int);");
            $migration = require database_path('migrations/2026_11_21_074344_initialize_uy1_registration_2026_2027.php');
            $migration->up();
            $migration->up();
            $this->assertSame(7, DB::table('gnu.faculte')->count());
            $this->assertSame(54, DB::table('gnu.departement')->count());
            $this->assertSame(27, DB::table('gnu.filiere')->count());
            $this->assertSame(2, DB::table('gnu.classe')->count());
            $this->assertSame(1, DB::table('gnu.classe')->where('id', 1)->value('annee_id'));
            $this->assertSame(1, DB::table('gnu.annee_academique')->where('libelle', '2026-2027')->count());
        } finally {
            DB::rollBack();
        }
    }

    private function connectIsolatedDatabase(): void
    {
        $socket = getenv('GNU_TRANSCRIPT_TEST_SOCKET');
        if (! $socket) {
            $this->markTestSkipped('Requires an isolated PostgreSQL socket and the compiled transcript renderer.');
        }
        config(['academic.active_year' => '2025-2026', 'database.connections.pgsql.host' => $socket, 'database.connections.pgsql.port' => 55436,
            'database.connections.pgsql.database' => 'postgres', 'database.connections.pgsql.username' => 'gnu_test',
            'database.connections.pgsql.password' => '']);
        DB::purge('pgsql');
    }
}
