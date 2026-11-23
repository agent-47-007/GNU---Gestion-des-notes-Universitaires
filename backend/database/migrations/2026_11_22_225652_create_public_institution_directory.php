<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('gnu.annuaire_institution', function (Blueprint $table): void {
            $table->id();
            $table->string('source_key', 80)->unique();
            $table->text('nom');
            $table->text('recherche');
            $table->string('categorie', 40)->index();
            $table->string('region', 80)->nullable()->index();
            $table->string('ville', 120)->nullable();
            $table->text('site_web')->nullable();
            $table->text('source_url');
            $table->text('source_liste_url');
            $table->date('source_date')->nullable();
            $table->date('consulte_le');
            $table->string('verification', 60);
            $table->unsignedBigInteger('universite_id')->nullable();
            $table->foreign('universite_id')->references('id')->on('gnu.universite')->nullOnDelete();
            $table->timestampsTz();
        });
        Schema::create('gnu.annuaire_metadata', function (Blueprint $table): void {
            $table->string('cle')->primary();
            $table->jsonb('contenu');
            $table->timestampTz('updated_at');
        });
        DB::statement('GRANT SELECT ON gnu.annuaire_institution, gnu.annuaire_metadata TO gnu_app');
    }

    public function down(): void
    {
        Schema::dropIfExists('gnu.annuaire_institution');
        Schema::dropIfExists('gnu.annuaire_metadata');
    }
};
