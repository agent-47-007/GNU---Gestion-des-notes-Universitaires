<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::statement("ALTER TABLE gnu.note_hors_compte ALTER COLUMN observation SET DEFAULT 'Étudiant non inscrit dans cette classe ou cette UE; à vérifier par l’agent.'");
        DB::table('gnu.note_hors_compte')->where('observation', 'Étudiant sans compte sur la plateforme.')
            ->update(['observation' => 'Étudiant non inscrit dans cette classe ou cette UE; à vérifier par l’agent.']);
        DB::statement('ALTER TABLE gnu.transmission_note ADD COLUMN publie_par bigint REFERENCES gnu.utilisateur(id) ON DELETE RESTRICT');
        DB::statement('ALTER TABLE gnu.transmission_note ADD COLUMN publie_le timestamptz');
        DB::statement('UPDATE gnu.transmission_note tn
            SET publie_par = pv.publie_par, publie_le = pv.publie_le
            FROM gnu.proces_verbal_note pv
            WHERE pv.transmission_id = tn.id AND pv.publie_le IS NOT NULL');

        DB::statement('ALTER TABLE gnu.transmission_note DROP CONSTRAINT IF EXISTS transmission_note_statut_check');
        DB::statement('ALTER TABLE gnu.transmission_note DROP CONSTRAINT IF EXISTS transmission_note_check');
        DB::statement('ALTER TABLE gnu.transmission_note DROP CONSTRAINT IF EXISTS transmission_note_check1');
        DB::statement(<<<'SQL'
ALTER TABLE gnu.transmission_note
    ADD CONSTRAINT transmission_note_statut_check
        CHECK (statut IN ('TRANSMISE', 'A_VERIFIER', 'A_CORRIGER', 'VERIFIEE', 'VALIDEE_ENSEIGNANT', 'PUBLIEE')),
    ADD CONSTRAINT transmission_note_traitement_check CHECK (
        (statut IN ('A_VERIFIER', 'A_CORRIGER', 'VERIFIEE') AND traite_par IS NOT NULL AND traite_le IS NOT NULL)
        OR (statut IN ('TRANSMISE', 'VALIDEE_ENSEIGNANT', 'PUBLIEE') AND traite_par IS NULL AND traite_le IS NULL)
    ),
    ADD CONSTRAINT transmission_note_validation_check CHECK (
        (statut IN ('VERIFIEE', 'VALIDEE_ENSEIGNANT', 'PUBLIEE') AND verifie_par IS NOT NULL AND verifie_le IS NOT NULL)
        OR (statut IN ('TRANSMISE', 'A_VERIFIER', 'A_CORRIGER') AND verifie_par IS NULL AND verifie_le IS NULL)
    ),
    ADD CONSTRAINT transmission_note_publication_check CHECK (
        statut <> 'PUBLIEE' OR (publie_par IS NOT NULL AND publie_le IS NOT NULL)
    )
SQL);

        DB::statement('DROP INDEX IF EXISTS gnu.transmission_note_ouverte_unique');
        DB::statement("CREATE UNIQUE INDEX transmission_note_ouverte_unique
            ON gnu.transmission_note (evaluation_id)
            WHERE statut IN ('TRANSMISE', 'A_VERIFIER', 'VALIDEE_ENSEIGNANT')");
    }

    public function down(): void
    {
        if (DB::table('gnu.transmission_note')->whereIn('statut', ['VALIDEE_ENSEIGNANT', 'PUBLIEE'])->exists()) {
            throw new RuntimeException('Des notes ont déjà été validées directement par un enseignant; leur workflow ne peut pas être annulé sans les archiver.');
        }

        DB::statement('DROP INDEX IF EXISTS gnu.transmission_note_ouverte_unique');
        DB::statement("CREATE UNIQUE INDEX transmission_note_ouverte_unique
            ON gnu.transmission_note (evaluation_id)
            WHERE statut IN ('TRANSMISE', 'A_VERIFIER')");
        DB::statement('ALTER TABLE gnu.transmission_note DROP CONSTRAINT IF EXISTS transmission_note_traitement_check');
        DB::statement('ALTER TABLE gnu.transmission_note DROP CONSTRAINT IF EXISTS transmission_note_validation_check');
        DB::statement('ALTER TABLE gnu.transmission_note DROP CONSTRAINT IF EXISTS transmission_note_publication_check');
        DB::statement('ALTER TABLE gnu.transmission_note DROP CONSTRAINT IF EXISTS transmission_note_statut_check');
        DB::statement(<<<'SQL'
ALTER TABLE gnu.transmission_note
    ADD CONSTRAINT transmission_note_statut_check
        CHECK (statut IN ('TRANSMISE', 'A_VERIFIER', 'A_CORRIGER', 'VERIFIEE')),
    ADD CONSTRAINT transmission_note_check CHECK (
        (statut IN ('A_VERIFIER', 'A_CORRIGER', 'VERIFIEE') AND traite_par IS NOT NULL AND traite_le IS NOT NULL)
        OR statut = 'TRANSMISE'
    ),
    ADD CONSTRAINT transmission_note_check1 CHECK (
        (statut = 'VERIFIEE' AND verifie_par IS NOT NULL AND verifie_le IS NOT NULL)
        OR statut <> 'VERIFIEE'
    )
SQL);
        DB::statement('ALTER TABLE gnu.transmission_note DROP COLUMN publie_le');
        DB::statement('ALTER TABLE gnu.transmission_note DROP COLUMN publie_par');
        DB::table('gnu.note_hors_compte')->where('observation', 'Étudiant non inscrit dans cette classe ou cette UE; à vérifier par l’agent.')
            ->update(['observation' => 'Étudiant sans compte sur la plateforme.']);
        DB::statement("ALTER TABLE gnu.note_hors_compte ALTER COLUMN observation SET DEFAULT 'Étudiant sans compte sur la plateforme.'");
    }
};
