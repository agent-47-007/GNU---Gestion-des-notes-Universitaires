<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        $definition = DB::selectOne("SELECT pg_get_functiondef('gnu.controle_requete()'::regprocedure) AS definition")->definition;

        $teacherAuthorization = <<<'SQL'
        PERFORM exiger(
            EXISTS (
                SELECT 1 FROM affectation af
                JOIN enseignant en ON en.id = af.enseignant_id
                WHERE af.actif AND af.classe_id = ci.classe_id AND af.matiere_id = NEW.matiere_id
                    AND en.utilisateur_id = acteur()
            ),
            'Traitement réservé à l’enseignant'
        );
SQL;

        $teacherOrAgentAuthorization = <<<'SQL'
        PERFORM exiger(
            EXISTS (
                SELECT 1 FROM affectation af
                JOIN enseignant en ON en.id = af.enseignant_id
                WHERE af.actif AND af.classe_id = ci.classe_id AND af.matiere_id = NEW.matiere_id
                    AND en.utilisateur_id = acteur()
            )
            OR EXISTS (
                SELECT 1
                FROM agent_departement ad
                JOIN classe c ON c.id = ci.classe_id
                JOIN niveau n ON n.id = c.niveau_id
                JOIN filiere f ON f.id = n.filiere_id
                JOIN utilisateur us ON us.id = acteur()
                WHERE ad.agent_id = us.id
                    AND ad.departement_id = f.departement_id
                    AND us.role = 'AGENT'
                    AND us.actif
            ),
            'Traitement réservé à l’enseignant ou à l’agent du département'
        );
SQL;

        if (! str_contains($definition, $teacherAuthorization)) {
            throw new RuntimeException('Le corps actuel de gnu.controle_requete() ne correspond pas à la version attendue.');
        }

        DB::unprepared(str_replace($teacherAuthorization, $teacherOrAgentAuthorization, $definition));
    }

    public function down(): void
    {
        // Revert the authorization clause to the previous teacher-only rule.
        $definition = DB::selectOne("SELECT pg_get_functiondef('gnu.controle_requete()'::regprocedure) AS definition")->definition;
        $teacherOrAgentAuthorization = <<<'SQL'
        PERFORM exiger(
            EXISTS (
                SELECT 1 FROM affectation af
                JOIN enseignant en ON en.id = af.enseignant_id
                WHERE af.actif AND af.classe_id = ci.classe_id AND af.matiere_id = NEW.matiere_id
                    AND en.utilisateur_id = acteur()
            )
            OR EXISTS (
                SELECT 1
                FROM agent_departement ad
                JOIN classe c ON c.id = ci.classe_id
                JOIN niveau n ON n.id = c.niveau_id
                JOIN filiere f ON f.id = n.filiere_id
                JOIN utilisateur us ON us.id = acteur()
                WHERE ad.agent_id = us.id
                    AND ad.departement_id = f.departement_id
                    AND us.role = 'AGENT'
                    AND us.actif
            ),
            'Traitement réservé à l’enseignant ou à l’agent du département'
        );
SQL;

        $teacherAuthorization = <<<'SQL'
        PERFORM exiger(
            EXISTS (
                SELECT 1 FROM affectation af
                JOIN enseignant en ON en.id = af.enseignant_id
                WHERE af.actif AND af.classe_id = ci.classe_id AND af.matiere_id = NEW.matiere_id
                    AND en.utilisateur_id = acteur()
            ),
            'Traitement réservé à l’enseignant'
        );
SQL;

        if (! str_contains($definition, $teacherOrAgentAuthorization)) {
            throw new RuntimeException('La clause d’autorisation agent est absente de gnu.controle_requete().');
        }

        DB::unprepared(str_replace($teacherOrAgentAuthorization, $teacherAuthorization, $definition));
    }
};
