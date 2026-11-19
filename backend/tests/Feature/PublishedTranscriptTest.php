<?php

namespace Tests\Feature;

use App\Models\Etudiant;
use App\Models\Enseignant;
use App\Models\Utilisateur;
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
                $user->setRelation('etudiant', new Etudiant());
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
            $teacher->setRelation('enseignant', new Enseignant());
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

    private function connectIsolatedDatabase(): void
    {
        $socket = getenv('GNU_TRANSCRIPT_TEST_SOCKET');
        if (! $socket) {
            $this->markTestSkipped('Requires an isolated PostgreSQL socket and the compiled transcript renderer.');
        }
        config(['database.connections.pgsql.host' => $socket, 'database.connections.pgsql.port' => 55436,
            'database.connections.pgsql.database' => 'postgres', 'database.connections.pgsql.username' => 'gnu_test',
            'database.connections.pgsql.password' => '']);
        DB::purge('pgsql');
    }
}
