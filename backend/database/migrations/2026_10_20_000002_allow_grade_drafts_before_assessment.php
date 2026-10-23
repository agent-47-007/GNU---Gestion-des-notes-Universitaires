<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        $this->rewriteNoteTrigger(
            "~ev\\.statut_evaluation\\s*=\\s*'REALISEE'\\s*,\\s*'Évaluation non réalisée'~u",
            "ev.statut_evaluation = 'REALISEE' OR NEW.statut_note = 'BROUILLON', 'Évaluation non réalisée'",
        );
    }

    public function down(): void
    {
        $this->rewriteNoteTrigger(
            "~ev\\.statut_evaluation\\s*=\\s*'REALISEE'\\s+OR\\s+NEW\\.statut_note\\s*=\\s*'BROUILLON'\\s*,\\s*'Évaluation non réalisée'~u",
            "ev.statut_evaluation = 'REALISEE', 'Évaluation non réalisée'",
        );
    }

    private function rewriteNoteTrigger(string $pattern, string $replacement): void
    {
        $definition = DB::scalar("SELECT pg_get_functiondef('gnu.controle_note()'::regprocedure)");
        if (! is_string($definition) || $definition === '') {
            throw new RuntimeException('La fonction de contrôle des notes gnu.controle_note() est introuvable.');
        }

        $updated = preg_replace($pattern, $replacement, $definition, -1, $matches);
        if (! is_string($updated) || $matches !== 1) {
            throw new RuntimeException('Impossible de modifier sûrement le contrôle de réalisation des évaluations. Aucun changement n’a été appliqué.');
        }

        DB::unprepared($updated);
    }
};
