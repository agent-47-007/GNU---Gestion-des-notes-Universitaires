<?php

use Illuminate\Database\Migrations\Migration;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        DB::statement('GRANT EXECUTE ON FUNCTION gnu.exiger(boolean, text) TO gnu_app');
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        DB::statement('REVOKE EXECUTE ON FUNCTION gnu.exiger(boolean, text) FROM gnu_app');
    }
};
