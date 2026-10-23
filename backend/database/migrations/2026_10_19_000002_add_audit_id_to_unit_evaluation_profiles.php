<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::statement('ALTER TABLE gnu.profil_evaluation_ue ADD COLUMN id bigint GENERATED ALWAYS AS IDENTITY');
        DB::statement('ALTER TABLE gnu.profil_evaluation_ue DROP CONSTRAINT profil_evaluation_ue_pkey');
        DB::statement('ALTER TABLE gnu.profil_evaluation_ue ADD CONSTRAINT profil_evaluation_ue_pkey PRIMARY KEY (id)');
        DB::statement('ALTER TABLE gnu.profil_evaluation_ue ADD CONSTRAINT profil_evaluation_ue_ue_id_unique UNIQUE (ue_id)');
        DB::statement('GRANT USAGE, SELECT ON SEQUENCE gnu.profil_evaluation_ue_id_seq TO gnu_app');
    }

    public function down(): void
    {
        DB::statement('REVOKE USAGE, SELECT ON SEQUENCE gnu.profil_evaluation_ue_id_seq FROM gnu_app');
        DB::statement('ALTER TABLE gnu.profil_evaluation_ue DROP CONSTRAINT profil_evaluation_ue_ue_id_unique');
        DB::statement('ALTER TABLE gnu.profil_evaluation_ue DROP CONSTRAINT profil_evaluation_ue_pkey');
        DB::statement('ALTER TABLE gnu.profil_evaluation_ue DROP COLUMN id');
        DB::statement('ALTER TABLE gnu.profil_evaluation_ue ADD CONSTRAINT profil_evaluation_ue_pkey PRIMARY KEY (ue_id)');
    }
};
