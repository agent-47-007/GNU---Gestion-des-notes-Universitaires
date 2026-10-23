<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::statement('GRANT SELECT, INSERT, UPDATE ON gnu.note TO gnu_app');
        DB::unprepared(<<<'SQL'
DO $$
DECLARE note_sequence regclass;
BEGIN
    note_sequence := pg_get_serial_sequence('gnu.note', 'id')::regclass;
    IF note_sequence IS NOT NULL THEN
        EXECUTE format('GRANT USAGE, SELECT ON SEQUENCE %s TO gnu_app', note_sequence);
    END IF;
END
$$;
SQL);
    }

    public function down(): void
    {
        DB::statement('REVOKE SELECT, INSERT, UPDATE ON gnu.note FROM gnu_app');
        DB::unprepared(<<<'SQL'
DO $$
DECLARE note_sequence regclass;
BEGIN
    note_sequence := pg_get_serial_sequence('gnu.note', 'id')::regclass;
    IF note_sequence IS NOT NULL THEN
        EXECUTE format('REVOKE USAGE, SELECT ON SEQUENCE %s FROM gnu_app', note_sequence);
    END IF;
END
$$;
SQL);
    }
};
