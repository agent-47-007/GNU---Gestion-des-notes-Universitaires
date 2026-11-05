<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::statement('ALTER TABLE gnu.evaluation ADD COLUMN heure_debut time NULL');
        DB::statement('ALTER TABLE gnu.evaluation ADD COLUMN heure_fin time NULL');
        DB::statement('ALTER TABLE gnu.evaluation ADD COLUMN salle varchar(32) NULL');
        DB::statement('ALTER TABLE gnu.evaluation ADD COLUMN programme_par bigint NULL REFERENCES gnu.utilisateur(id) ON DELETE RESTRICT');
        DB::statement("ALTER TABLE gnu.evaluation ADD CONSTRAINT evaluation_horaire_coherent CHECK ((heure_debut IS NULL AND heure_fin IS NULL AND salle IS NULL AND programme_par IS NULL) OR (heure_debut IS NOT NULL AND heure_fin IS NOT NULL AND heure_fin > heure_debut AND salle ~ '^[A-Za-z0-9][A-Za-z0-9-]{0,31}$' AND programme_par IS NOT NULL))");

        DB::statement('ALTER TABLE gnu.session_rattrapage ADD COLUMN heure_debut time NULL');
        DB::statement('ALTER TABLE gnu.session_rattrapage ADD COLUMN heure_fin time NULL');
        DB::statement('ALTER TABLE gnu.session_rattrapage ADD COLUMN salle varchar(32) NULL');
        DB::statement("ALTER TABLE gnu.session_rattrapage ADD CONSTRAINT session_rattrapage_horaire_coherent CHECK ((heure_debut IS NULL AND heure_fin IS NULL AND salle IS NULL) OR (heure_debut IS NOT NULL AND heure_fin IS NOT NULL AND heure_fin > heure_debut AND salle ~ '^[A-Za-z0-9][A-Za-z0-9-]{0,31}$'))");

        DB::statement('ALTER TABLE gnu.notification DROP CONSTRAINT notification_type_notification_check');
        DB::statement("ALTER TABLE gnu.notification ADD CONSTRAINT notification_type_notification_check CHECK (type_notification IN ('RAPPEL_NOTES', 'REQUETE_DEPOSEE', 'REQUETE_DECIDEE', 'PUBLICATION', 'INSCRIPTION_DECIDEE', 'SESSION_RATTRAPAGE', 'MESSAGE_ENSEIGNANT', 'SESSION_NORMALE', 'AFFECTATION_DECIDEE'))");
    }

    public function down(): void
    {
        if (DB::table('gnu.evaluation')->whereNotNull('programme_par')->exists()
            || DB::table('gnu.session_rattrapage')->whereNotNull('salle')->exists()
            || DB::table('gnu.notification')->whereIn('type_notification', [
                'SESSION_NORMALE', 'AFFECTATION_DECIDEE', 'MESSAGE_ENSEIGNANT',
            ])->exists()) {
            throw new RuntimeException('Des horaires ou notifications de session normale existent; archivez-les avant de retirer ces champs.');
        }

        DB::statement('ALTER TABLE gnu.notification DROP CONSTRAINT notification_type_notification_check');
        DB::statement("ALTER TABLE gnu.notification ADD CONSTRAINT notification_type_notification_check CHECK (type_notification IN ('RAPPEL_NOTES', 'REQUETE_DEPOSEE', 'REQUETE_DECIDEE', 'PUBLICATION', 'INSCRIPTION_DECIDEE', 'SESSION_RATTRAPAGE', 'MESSAGE_ENSEIGNANT'))");
        DB::statement('ALTER TABLE gnu.session_rattrapage DROP CONSTRAINT session_rattrapage_horaire_coherent');
        DB::statement('ALTER TABLE gnu.session_rattrapage DROP COLUMN heure_debut, DROP COLUMN heure_fin, DROP COLUMN salle');
        DB::statement('ALTER TABLE gnu.evaluation DROP CONSTRAINT evaluation_horaire_coherent');
        DB::statement('ALTER TABLE gnu.evaluation DROP COLUMN programme_par, DROP COLUMN salle, DROP COLUMN heure_fin, DROP COLUMN heure_debut');
    }
};
