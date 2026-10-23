<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::statement('GRANT EXECUTE ON FUNCTION gnu.acteur() TO gnu_app');
    }

    public function down(): void
    {
        DB::statement('REVOKE EXECUTE ON FUNCTION gnu.acteur() FROM gnu_app');
    }
};
