<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('gnu.annuaire_structure_source', function (Blueprint $table): void {
            $table->string('source_key', 64)->primary();
            $table->string('objet_type', 20);
            $table->bigInteger('objet_id');
            $table->text('source_url');
            $table->date('consulte_le');
            $table->date('source_date')->nullable();
            $table->string('annee_source', 9)->nullable();
            $table->jsonb('details');
            $table->index(['objet_type', 'objet_id']);
        });
        DB::statement('GRANT SELECT ON gnu.annuaire_structure_source TO gnu_app');
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('gnu.annuaire_structure_source');
    }
};
