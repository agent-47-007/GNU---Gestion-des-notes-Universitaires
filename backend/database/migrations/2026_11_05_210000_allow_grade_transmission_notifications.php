<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::statement('ALTER TABLE gnu.notification DROP CONSTRAINT notification_type_notification_check');
        DB::statement("ALTER TABLE gnu.notification ADD CONSTRAINT notification_type_notification_check CHECK (type_notification IN ('RAPPEL_NOTES', 'REQUETE_DEPOSEE', 'REQUETE_DECIDEE', 'PUBLICATION', 'INSCRIPTION_DECIDEE', 'SESSION_RATTRAPAGE', 'MESSAGE_ENSEIGNANT', 'SESSION_NORMALE', 'AFFECTATION_DECIDEE', 'TRANSMISSION_NOTE'))");
    }

    public function down(): void
    {
        if (DB::table('gnu.notification')->where('type_notification', 'TRANSMISSION_NOTE')->exists()) {
            throw new RuntimeException('Des notifications de transmission de notes existent; archivez-les avant de retirer ce type.');
        }

        DB::statement('ALTER TABLE gnu.notification DROP CONSTRAINT notification_type_notification_check');
        DB::statement("ALTER TABLE gnu.notification ADD CONSTRAINT notification_type_notification_check CHECK (type_notification IN ('RAPPEL_NOTES', 'REQUETE_DEPOSEE', 'REQUETE_DECIDEE', 'PUBLICATION', 'INSCRIPTION_DECIDEE', 'SESSION_RATTRAPAGE', 'MESSAGE_ENSEIGNANT', 'SESSION_NORMALE', 'AFFECTATION_DECIDEE'))");
    }
};
