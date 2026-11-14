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

        DB::unprepared(<<<'SQL'
GRANT EXECUTE ON FUNCTION gnu.calculer_ec(bigint, bigint) TO gnu_app;
GRANT EXECUTE ON FUNCTION gnu.calculer_ue(bigint) TO gnu_app;
SQL);
    }

    public function down(): void
    {
        DB::unprepared(<<<'SQL'
REVOKE EXECUTE ON FUNCTION gnu.calculer_ec(bigint, bigint) FROM gnu_app;
REVOKE EXECUTE ON FUNCTION gnu.calculer_ue(bigint) FROM gnu_app;
SQL);
    }
};
