<?php

namespace App\Services;

use DomainException;

class AcademicRules
{
    /**
     * @param  array<string, int|float>  $weights
     */
    public function validateEvaluationWeights(array $weights): void
    {
        if ($weights === []) {
            throw new DomainException('Le plan d’évaluation doit contenir au moins une composante.');
        }

        foreach ($weights as $weight) {
            if (! is_numeric($weight) || $weight < 0 || $weight > 100) {
                throw new DomainException('Chaque pondération doit être comprise entre 0 et 100 %.');
            }
        }

        if (abs((float) array_sum($weights) - (float) config('academic.evaluation_total_weight', 100)) > 0.0001) {
            throw new DomainException('La somme des pondérations doit être égale à 100 %.');
        }
    }

    /**
     * @param  list<array{type_eval: string, poids: int|float|string}>  $evaluations
     */
    public function validateOfficialEvaluationWeights(array $evaluations): void
    {
        $totals = [];
        foreach ($evaluations as $evaluation) {
            $type = strtoupper(trim($evaluation['type_eval']));
            if (! in_array($type, ['CC', 'TP', 'TPE', 'SN'], true)) {
                throw new DomainException('Le type d’évaluation doit être CC, TP, TPE ou SN.');
            }
            $totals[$type] = ($totals[$type] ?? 0.0) + (float) $evaluation['poids'];
        }

        $profiles = [
            ['CC' => 30.0, 'SN' => 70.0],
            ['CC' => 20.0, 'TPE' => 20.0, 'SN' => 60.0],
            ['CC' => 20.0, 'TP' => 30.0, 'SN' => 50.0],
        ];
        foreach ($profiles as $profile) {
            $matches = true;
            foreach (['CC', 'TP', 'TPE', 'SN'] as $type) {
                if (abs(($totals[$type] ?? 0.0) - ($profile[$type] ?? 0.0)) > 0.0001) {
                    $matches = false;
                    break;
                }
            }
            if ($matches) {
                return;
            }
        }

        throw new DomainException(
            'Respectez la grille officielle : CC 30 % + SN 70 % ; avec TPE, CC 20 % + TPE 20 % + SN 60 % ; pour une UE mixte, CC 20 % + TP 30 % + SN 50 %.'
        );
    }

    /**
     * @param  array<string, array{weight: int|float, status: string, mark?: int|float|null}>  $components
     * @return array{status: string, mark: ?float, decision: ?string}
     */
    public function calculateFinalMark(array $components): array
    {
        $weights = [];
        foreach ($components as $code => $component) {
            $weights[$code] = $component['weight'];
        }
        $this->validateEvaluationWeights($weights);

        $weightedTotal = 0.0;
        $incomplete = false;
        foreach ($components as $component) {
            $status = strtoupper($component['status']);
            if (in_array($status, ['ABSENT', 'ABSENTE'], true)) {
                return ['status' => 'ABSENT', 'mark' => null, 'decision' => null];
            }
            if (in_array($status, ['ELIMINEE', 'EL'], true)) {
                return ['status' => 'ELIMINEE', 'mark' => null, 'decision' => 'ECHEC'];
            }
            if (in_array($status, ['MANQUANTE', 'INCOMPLETE'], true)) {
                $incomplete = true;

                continue;
            }
            if ($status !== 'PRESENT' || ! isset($component['mark']) || ! is_numeric($component['mark'])) {
                throw new DomainException('Chaque composante doit avoir un statut explicite et une note si elle est présente.');
            }

            $mark = (float) $component['mark'];
            if ($mark < 0 || $mark > (float) config('academic.mark_scale', 20)) {
                throw new DomainException('Chaque note doit être comprise entre 0 et 20.');
            }

            $weightedTotal += $mark * (float) $component['weight'];
        }

        if ($incomplete) {
            return ['status' => 'INCOMPLETE', 'mark' => null, 'decision' => null];
        }

        $finalMark = round(
            $weightedTotal / (float) config('academic.evaluation_total_weight', 100),
            (int) config('academic.mark_rounding_decimals', 2),
        );

        return [
            'status' => 'CALCULEE',
            'mark' => $finalMark,
            'decision' => $finalMark >= (float) config('academic.passing_mark', 10) ? 'ACQUISE' : 'NON_ACQUISE',
        ];
    }

    public function isRetakeEligible(float $mark, int $existingSessions = 0): bool
    {
        return $existingSessions < (int) config('academic.retake_max_sessions', 1)
            && $mark >= (float) config('academic.retake_minimum_mark', 0)
            && $mark <= (float) config('academic.retake_maximum_inclusive', 10);
    }

    /** @param array<string, mixed> $snapshot */
    public function markForUnitSnapshot(array $snapshot, string $code): ?float
    {
        $rows = $snapshot['ues'] ?? $snapshot['resultats_ue'] ?? $snapshot['resultats'] ?? $snapshot['lignes'] ?? [];
        if (! is_array($rows)) {
            return null;
        }

        foreach ($rows as $row) {
            if (! is_array($row) || ($row['code_ue'] ?? $row['code'] ?? null) !== $code) {
                continue;
            }
            if (is_numeric($row['note_sur_20'] ?? null)) {
                return (float) $row['note_sur_20'];
            }
            foreach (['note_sur_100', 'note_finale_sur_100', 'arrondi'] as $field) {
                if (is_numeric($row[$field] ?? null)) {
                    return round((float) $row[$field] / 5, 2);
                }
            }
            $mark = $row['note_finale'] ?? $row['note'] ?? $row['mark'] ?? null;

            return is_numeric($mark) ? (float) $mark : null;
        }

        return null;
    }
}
