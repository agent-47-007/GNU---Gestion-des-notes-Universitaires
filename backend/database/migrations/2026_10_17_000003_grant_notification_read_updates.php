<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::statement('GRANT UPDATE ON gnu.notification TO gnu_app');
    }

    public function down(): void
    {
        DB::statement('REVOKE UPDATE ON gnu.notification FROM gnu_app');
    }
};
