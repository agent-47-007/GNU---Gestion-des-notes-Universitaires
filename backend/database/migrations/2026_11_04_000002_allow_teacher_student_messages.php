<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::statement('ALTER TABLE gnu.notification DROP CONSTRAINT notification_type_notification_check');
        DB::statement("ALTER TABLE gnu.notification ADD CONSTRAINT notification_type_notification_check CHECK (type_notification IN ('RAPPEL_NOTES', 'REQUETE_DEPOSEE', 'REQUETE_DECIDEE', 'PUBLICATION', 'INSCRIPTION_DECIDEE', 'SESSION_RATTRAPAGE', 'MESSAGE_ENSEIGNANT'))");
    }

    public function down(): void
    {
        if (DB::table('gnu.notification')->where('type_notification', 'MESSAGE_ENSEIGNANT')->exists()) {
            throw new RuntimeException('Des messages d’enseignant existent; archivez-les avant de retirer cette fonctionnalité.');
        }

        DB::statement('ALTER TABLE gnu.notification DROP CONSTRAINT notification_type_notification_check');
        DB::statement("ALTER TABLE gnu.notification ADD CONSTRAINT notification_type_notification_check CHECK (type_notification IN ('RAPPEL_NOTES', 'REQUETE_DEPOSEE', 'REQUETE_DECIDEE', 'PUBLICATION', 'INSCRIPTION_DECIDEE', 'SESSION_RATTRAPAGE'))");
    }
};
