<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        if (DB::getDriverName() !== 'pgsql') {
            throw new RuntimeException('Cette migration métier doit être exécutée sur PostgreSQL.');
        }

        $definition = DB::scalar("SELECT pg_get_functiondef('gnu.calculer_ec(bigint,bigint)'::regprocedure)");
        if (! is_string($definition) || $definition === '') {
            throw new RuntimeException('La fonction de calcul des EC GNU est absente.');
        }

        $definition = $this->replaceExactlyOnce(
            $definition,
            '~IF a\.id IS NULL THEN\s+RETURN jsonb_build_object\(.*?\);\s+END IF;~s',
            "IF a.id IS NULL THEN\n        RAISE EXCEPTION USING ERRCODE='23514', MESSAGE=format('Publication bloquée : aucun responsable actif pour l’UE %s dans la classe %s', ci.ue_id, ci.classe_id);\n    END IF;",
            'contrôle de l’affectation responsable',
        );

        $definition = $this->replaceExactlyOnce(
            $definition,
            '~IF p\.id IS NULL THEN\s+RETURN jsonb_build_object\(.*?\);\s+END IF;~s',
            "IF p.id IS NULL THEN\n        RAISE EXCEPTION USING ERRCODE='23514', MESSAGE=format('Publication bloquée : aucune grille active pour l’UE %s dans la classe %s', ci.ue_id, ci.classe_id);\n    END IF;",
            'contrôle de la grille active',
        );

        $definition = $this->replaceExactlyOnce(
            $definition,
            '~IF total IS DISTINCT FROM 100 OR NOT plan_evaluation_types_valid\(p\.id\) THEN\s+RETURN jsonb_build_object\(.*?\);\s+END IF;~s',
            "IF total IS DISTINCT FROM 100 OR NOT plan_evaluation_types_valid(p.id) THEN\n        RAISE EXCEPTION USING ERRCODE='23514', MESSAGE=format('Publication bloquée : la grille active de l’UE %s est invalide', ci.ue_id);\n    END IF;",
            'contrôle de la pondération officielle',
        );

        $definition = $this->replaceExactlyOnce(
            $definition,
            '~IF n\.id IS NULL OR n\.statut_note<>\'VALIDEE\' OR n\.situation<>\'NUMERIQUE\' OR n\.valeur_note IS NULL THEN\s+elim:=true;\s+sources:=sources\|\|jsonb_build_array\(jsonb_build_object\(.*?\)\);\s+CONTINUE;\s+END IF;~s',
            <<<'SQL'
IF n.id IS NULL OR n.statut_note<>'VALIDEE' THEN
            RAISE EXCEPTION USING ERRCODE='23514', MESSAGE=format('Publication bloquée : une note manque ou n’est pas validée (évaluation %s, inscription UE %s)', l.evaluation_id, iu);
        END IF;
        IF n.situation='ABSENTE' THEN
            elim:=true;
            sources:=sources||jsonb_build_array(jsonb_build_object('evaluation_origine_id',l.evaluation_id,
                'evaluation_id',n.evaluation_id,'note_id',n.id,'version_note',n.version_note,
                'valeur',n.valeur_note,'situation',n.situation,'statut_note',n.statut_note,
                'poids',gnu.poids_officiel_evaluation(p.id,l.evaluation_id),
                'poids_plan',l.poids_evaluation,'el',true));
            CONTINUE;
        END IF;
        IF n.situation<>'NUMERIQUE' OR n.valeur_note IS NULL THEN
            RAISE EXCEPTION USING ERRCODE='23514', MESSAGE=format('Publication bloquée : la situation de note doit être contrôlée (évaluation %s, inscription UE %s)', l.evaluation_id, iu);
        END IF;
SQL,
            'blocage des notes absentes du circuit de validation',
        );

        DB::unprepared($definition);

        foreach ([
            'gnu.calculer_bulletin(bigint,text)',
            'gnu.previsualiser_bulletin(bigint,text)',
            'gnu.controle_publication()',
        ] as $signature) {
            $ruleFunction = DB::scalar('SELECT pg_get_functiondef(?::regprocedure)', [$signature]);
            if (is_string($ruleFunction) && str_contains($ruleFunction, 'GNU-1.6')) {
                DB::unprepared(str_replace('GNU-1.6', 'GNU-1.7', $ruleFunction));
            }
        }

        DB::unprepared(<<<'SQL'
DO $$
DECLARE mgp_s1 numeric; mgp_s2 numeric; mgp_annuel numeric;
        admission_valide boolean; admission_sous_seuil_ue boolean;
        admission_sous_mgp boolean; admission_eliminatoire boolean;
BEGIN
    IF EXISTS (
        SELECT 1
        FROM (VALUES
            (0::numeric, 'F'::text, 0.00::numeric),
            (30, 'E', 0.00), (35, 'D', 1.00), (40, 'D+', 1.30),
            (45, 'C-', 1.70), (50, 'C', 2.00), (55, 'C+', 2.30),
            (60, 'B-', 2.70), (65, 'B', 3.00), (70, 'B+', 3.30),
            (75, 'A-', 3.70), (80, 'A', 4.00)
        ) AS attendu(note, grade, points)
        WHERE gnu.grade_ue(attendu.note) IS DISTINCT FROM attendu.grade
           OR gnu.points_ue(attendu.note) IS DISTINCT FROM attendu.points
    ) THEN
        RAISE EXCEPTION 'Contrôle MGP GNU échoué : le barème de grades ou de points diffère des règles officielles.';
    END IF;

    WITH resultats(semestre, note, credits, eliminatoire) AS (
        VALUES (1, 79.99::numeric, 6::numeric, false),
               (1, 35, 4, false),
               (2, 50, 6, false),
               (2, 65, 4, false)
    )
    SELECT
        round(sum(gnu.points_ue(note) * credits) FILTER (WHERE semestre = 1) / sum(credits) FILTER (WHERE semestre = 1), 2),
        round(sum(gnu.points_ue(note) * credits) FILTER (WHERE semestre = 2) / sum(credits) FILTER (WHERE semestre = 2), 2),
        round(sum(gnu.points_ue(note) * credits) / sum(credits), 2),
        min(note) >= 35
            AND round(sum(gnu.points_ue(note) * credits) / sum(credits), 2) >= 2
            AND bool_and(NOT eliminatoire)
    INTO mgp_s1, mgp_s2, mgp_annuel, admission_valide
    FROM resultats;

    IF mgp_s1 IS DISTINCT FROM 2.62 OR mgp_s2 IS DISTINCT FROM 2.40
       OR mgp_annuel IS DISTINCT FROM 2.51 OR admission_valide IS DISTINCT FROM true THEN
        RAISE EXCEPTION 'Contrôle MGP GNU échoué : moyenne semestrielle, annuelle ou admission incohérente.';
    END IF;

    WITH resultats(note, credits, eliminatoire) AS (
        VALUES (79.99::numeric, 6::numeric, false), (34.99, 4, false),
               (50, 6, false), (65, 4, false)
    )
    SELECT min(note) >= 35
        AND round(sum(gnu.points_ue(note) * credits) / sum(credits), 2) >= 2
        AND bool_and(NOT eliminatoire)
    INTO admission_sous_seuil_ue FROM resultats;

    WITH resultats(note, credits, eliminatoire) AS (
        VALUES (35::numeric, 6::numeric, false), (35, 4, false),
               (35, 6, false), (35, 4, false)
    )
    SELECT min(note) >= 35
        AND round(sum(gnu.points_ue(note) * credits) / sum(credits), 2) >= 2
        AND bool_and(NOT eliminatoire)
    INTO admission_sous_mgp FROM resultats;

    WITH resultats(note, credits, eliminatoire) AS (
        VALUES (80::numeric, 6::numeric, false), (80, 4, false),
               (80, 6, true), (80, 4, false)
    )
    SELECT min(note) >= 35
        AND round(sum(gnu.points_ue(note) * credits) / sum(credits), 2) >= 2
        AND bool_and(NOT eliminatoire)
    INTO admission_eliminatoire FROM resultats;

    IF admission_sous_seuil_ue IS DISTINCT FROM false
       OR admission_sous_mgp IS DISTINCT FROM false
       OR admission_eliminatoire IS DISTINCT FROM false THEN
        RAISE EXCEPTION 'Contrôle MGP GNU échoué : un seuil d’admission ou une élimination n’est pas appliqué.';
    END IF;
END $$;
SQL);
    }

    public function down(): void
    {
        throw new RuntimeException('Le contrôle strict des calculs officiels est une évolution métier versionnée; restaurez une sauvegarde validée pour revenir en arrière.');
    }

    private function replaceExactlyOnce(string $source, string $pattern, string $replacement, string $description): string
    {
        $count = 0;
        $updated = preg_replace($pattern, $replacement, $source, 1, $count);
        if ($updated === null || $count !== 1) {
            throw new RuntimeException("Impossible d’appliquer le contrôle « {$description} » exactement une fois.");
        }

        return $updated;
    }
};
