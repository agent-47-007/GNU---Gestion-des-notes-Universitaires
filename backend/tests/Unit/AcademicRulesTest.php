<?php

namespace Tests\Unit;

use App\Services\AcademicRules;
use DomainException;
use Tests\TestCase;

class AcademicRulesTest extends TestCase
{
    public function test_it_calculates_weighted_mark_on_twenty_and_rounds_to_two_decimals(): void
    {
        $result = (new AcademicRules)->calculateFinalMark([
            'CC' => ['weight' => 70, 'status' => 'PRESENT', 'mark' => 10.5],
            'EXAMEN' => ['weight' => 30, 'status' => 'PRESENT', 'mark' => 11],
        ]);

        $this->assertSame(['status' => 'CALCULEE', 'mark' => 10.65, 'decision' => 'ACQUISE'], $result);
    }

    public function test_it_does_not_turn_absence_or_missing_mark_into_zero(): void
    {
        $rules = new AcademicRules;
        $base = ['CC' => ['weight' => 100, 'status' => 'PRESENT', 'mark' => 18]];

        $this->assertSame(
            ['status' => 'ABSENT', 'mark' => null, 'decision' => null],
            $rules->calculateFinalMark(['CC' => ['weight' => 100, 'status' => 'ABSENT']]),
        );
        $this->assertSame(
            ['status' => 'INCOMPLETE', 'mark' => null, 'decision' => null],
            $rules->calculateFinalMark(['CC' => ['weight' => 100, 'status' => 'MANQUANTE']]),
        );
        $this->assertSame(18.0, $rules->calculateFinalMark($base)['mark']);
    }

    public function test_it_requires_assessment_weights_to_total_one_hundred_percent(): void
    {
        $this->expectException(DomainException::class);

        (new AcademicRules)->validateEvaluationWeights(['CC' => 40, 'EXAMEN' => 50]);
    }

    public function test_it_applies_retake_boundaries_and_single_session_limit(): void
    {
        $rules = new AcademicRules;

        $this->assertTrue($rules->isRetakeEligible(5));
        $this->assertTrue($rules->isRetakeEligible(9.99));
        $this->assertFalse($rules->isRetakeEligible(4.99));
        $this->assertFalse($rules->isRetakeEligible(10));
        $this->assertFalse($rules->isRetakeEligible(8, 1));
    }
}
