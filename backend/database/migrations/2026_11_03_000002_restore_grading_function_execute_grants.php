<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::statement('GRANT EXECUTE ON FUNCTION gnu.grade_ue(numeric), gnu.grade_ue(integer), gnu.points_ue(numeric), gnu.points_ue(integer) TO gnu_app');
    }

    public function down(): void
    {
        DB::statement('REVOKE EXECUTE ON FUNCTION gnu.grade_ue(numeric), gnu.grade_ue(integer), gnu.points_ue(numeric), gnu.points_ue(integer) FROM gnu_app');
    }
};
