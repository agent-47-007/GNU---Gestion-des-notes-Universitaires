<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::unprepared(<<<'SQL'
CREATE OR REPLACE FUNCTION gnu.journaliser()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'gnu', 'pg_catalog'
AS $function$
DECLARE
    av jsonb;
    ap jsonb;
    identifiant text;
BEGIN
    IF TG_OP <> 'INSERT' THEN
        av := to_jsonb(OLD) - 'mot_de_passe_hash';
    END IF;
    IF TG_OP <> 'DELETE' THEN
        ap := to_jsonb(NEW) - 'mot_de_passe_hash';
    END IF;

    identifiant := coalesce(
        ap->>'id', av->>'id',
        ap->>'agent_id', av->>'agent_id',
        ap::text, av::text
    );

    INSERT INTO journal_audit(acteur_id, origine, action, date_action, type_objet, identifiant_objet, avant, apres, motif)
    VALUES (
        acteur(),
        CASE WHEN acteur() IS NULL THEN 'SYSTEME' ELSE 'UTILISATEUR' END,
        TG_OP,
        statement_timestamp(),
        TG_TABLE_NAME,
        identifiant,
        av,
        ap,
        coalesce(nullif(current_setting('gnu.motif', true), ''), 'Opération SQL de gestion')
    );
    RETURN NULL;
END
$function$;
SQL);
    }

    public function down(): void
    {
        DB::unprepared(<<<'SQL'
CREATE OR REPLACE FUNCTION gnu.journaliser()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'gnu', 'pg_catalog'
AS $function$
DECLARE av jsonb; ap jsonb;
BEGIN
    IF TG_OP <> 'INSERT' THEN av := to_jsonb(OLD) - 'mot_de_passe_hash'; END IF;
    IF TG_OP <> 'DELETE' THEN ap := to_jsonb(NEW) - 'mot_de_passe_hash'; END IF;
    INSERT INTO journal_audit(acteur_id, origine, action, date_action, type_objet, identifiant_objet, avant, apres, motif)
    VALUES (acteur(), CASE WHEN acteur() IS NULL THEN 'SYSTEME' ELSE 'UTILISATEUR' END, TG_OP,
        statement_timestamp(), TG_TABLE_NAME, coalesce(ap->>'id', av->>'id'), av, ap,
        coalesce(nullif(current_setting('gnu.motif', true), ''), 'Opération SQL de gestion'));
    RETURN NULL;
END
$function$;
SQL);
    }
};
