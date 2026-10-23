<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        DB::statement('CREATE TABLE gnu_auth.personal_access_tokens (
            id BIGSERIAL PRIMARY KEY,
            tokenable_type VARCHAR(255) NOT NULL,
            tokenable_id BIGINT NOT NULL,
            name TEXT NOT NULL,
            token CHAR(64) NOT NULL UNIQUE,
            abilities TEXT NULL,
            last_used_at TIMESTAMPTZ NULL,
            expires_at TIMESTAMPTZ NULL,
            created_at TIMESTAMPTZ NULL,
            updated_at TIMESTAMPTZ NULL
        )');
        DB::statement('CREATE INDEX personal_access_tokens_tokenable_index ON gnu_auth.personal_access_tokens (tokenable_type, tokenable_id)');
        DB::statement('GRANT USAGE ON SCHEMA gnu_auth TO gnu_app');
        DB::statement('GRANT SELECT, INSERT, UPDATE, DELETE ON gnu_auth.personal_access_tokens TO gnu_app');
        DB::statement('GRANT USAGE, SELECT ON SEQUENCE gnu_auth.personal_access_tokens_id_seq TO gnu_app');
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        DB::statement('DROP TABLE gnu_auth.personal_access_tokens');
    }
};
