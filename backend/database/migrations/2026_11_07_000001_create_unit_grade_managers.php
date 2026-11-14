<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::unprepared(<<<'SQL'
CREATE TABLE gnu.responsable_note_ue (
    classe_id bigint NOT NULL REFERENCES gnu.classe(id) ON DELETE RESTRICT,
    ue_id bigint NOT NULL REFERENCES gnu.ue(id) ON DELETE RESTRICT,
    enseignant_id bigint NOT NULL REFERENCES gnu.enseignant(id) ON DELETE RESTRICT,
    created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
    updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
    PRIMARY KEY (classe_id, ue_id)
);

-- Existing classes keep one responsible teacher per UE, selected by the largest
-- number of active EC assignments, then by the stable teacher identifier.
INSERT INTO gnu.responsable_note_ue (classe_id, ue_id, enseignant_id)
SELECT classe_id, ue_id, enseignant_id
FROM (
    SELECT a.classe_id, m.ue_id, a.enseignant_id,
           row_number() OVER (PARTITION BY a.classe_id, m.ue_id
               ORDER BY count(*) DESC, a.enseignant_id ASC) AS rang
    FROM gnu.affectation a
    JOIN gnu.matiere m ON m.id = a.matiere_id
    WHERE a.actif = true
    GROUP BY a.classe_id, m.ue_id, a.enseignant_id
) choix
WHERE rang = 1;

CREATE FUNCTION gnu.verifier_responsable_note_ue() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM gnu.affectation a
        JOIN gnu.matiere m ON m.id = a.matiere_id
        WHERE a.classe_id = NEW.classe_id
          AND m.ue_id = NEW.ue_id
          AND a.enseignant_id = NEW.enseignant_id
          AND a.actif = true
    ) THEN
        RAISE EXCEPTION 'Le responsable de saisie doit avoir une affectation active dans cette UE et cette classe.';
    END IF;
    NEW.updated_at := statement_timestamp();
    RETURN NEW;
END;
$$;
CREATE TRIGGER verifier_responsable_note_ue
    BEFORE INSERT OR UPDATE ON gnu.responsable_note_ue
    FOR EACH ROW EXECUTE FUNCTION gnu.verifier_responsable_note_ue();
CREATE TRIGGER zz_audit AFTER INSERT OR UPDATE OR DELETE ON gnu.responsable_note_ue
    FOR EACH ROW EXECUTE FUNCTION gnu.journaliser();
GRANT SELECT, INSERT, UPDATE, DELETE ON gnu.responsable_note_ue TO gnu_app;
SQL);
    }

    public function down(): void
    {
        DB::statement('DROP TABLE gnu.responsable_note_ue');
        DB::statement('DROP FUNCTION gnu.verifier_responsable_note_ue()');
    }
};
