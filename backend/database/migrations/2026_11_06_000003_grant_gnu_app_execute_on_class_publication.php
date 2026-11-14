<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        if (DB::getDriverName() !== 'pgsql') {
            throw new RuntimeException('Cette migration doit être exécutée sur PostgreSQL.');
        }

        DB::unprepared('GRANT EXECUTE ON FUNCTION gnu.publier_classe(bigint, text) TO gnu_app');
    }

    public function down(): void
    {
        DB::unprepared('REVOKE EXECUTE ON FUNCTION gnu.publier_classe(bigint, text) FROM gnu_app');
    }
};
