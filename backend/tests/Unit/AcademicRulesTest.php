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

    public function test_it_accepts_the_three_configured_official_ue_evaluation_profiles(): void
    {
        $rules = new AcademicRules;

        foreach ([
            [['type_eval' => 'CC', 'poids' => 30], ['type_eval' => 'SN', 'poids' => 70]],
            [['type_eval' => 'CC', 'poids' => 20], ['type_eval' => 'TP', 'poids' => 30], ['type_eval' => 'SN', 'poids' => 50]],
            [['type_eval' => 'CC', 'poids' => 20], ['type_eval' => 'TPE', 'poids' => 20], ['type_eval' => 'SN', 'poids' => 60]],
        ] as $profile) {
            $rules->validateOfficialEvaluationWeights($profile);
            $this->assertTrue(true);
        }
    }

    public function test_official_profiles_produce_the_expected_weighted_mark(): void
    {
        $rules = new AcademicRules;
        $cases = [
            [
                'profile' => [
                    'CC' => ['weight' => 30, 'status' => 'PRESENT', 'mark' => 10],
                    'SN' => ['weight' => 70, 'status' => 'PRESENT', 'mark' => 15],
                ],
                'expected' => 13.5,
            ],
            [
                'profile' => [
                    'CC' => ['weight' => 20, 'status' => 'PRESENT', 'mark' => 10],
                    'TP' => ['weight' => 30, 'status' => 'PRESENT', 'mark' => 12],
                    'SN' => ['weight' => 50, 'status' => 'PRESENT', 'mark' => 14],
                ],
                'expected' => 12.6,
            ],
            [
                'profile' => [
                    'CC' => ['weight' => 20, 'status' => 'PRESENT', 'mark' => 12],
                    'TPE' => ['weight' => 20, 'status' => 'PRESENT', 'mark' => 10],
                    'SN' => ['weight' => 60, 'status' => 'PRESENT', 'mark' => 15],
                ],
                'expected' => 13.4,
            ],
        ];

        foreach ($cases as $case) {
            $this->assertSame($case['expected'], $rules->calculateFinalMark($case['profile'])['mark']);
        }
    }

    public function test_official_plan_rejects_duplicate_assessment_types(): void
    {
        $this->expectException(DomainException::class);
        $this->expectExceptionMessage('Une seule évaluation de chaque type');

        (new AcademicRules)->validateOfficialEvaluationWeights([
            ['type_eval' => 'CC', 'poids' => 15],
            ['type_eval' => 'CC', 'poids' => 15],
            ['type_eval' => 'SN', 'poids' => 70],
        ]);
    }

    public function test_it_applies_retake_boundaries_and_single_session_limit(): void
    {
        $rules = new AcademicRules;

        $this->assertTrue($rules->isRetakeEligible(0));
        $this->assertTrue($rules->isRetakeEligible(7.5));
        $this->assertTrue($rules->isRetakeEligible(9.99));
        $this->assertFalse($rules->isRetakeEligible(10));
        $this->assertFalse($rules->isRetakeEligible(8, 1));
        $this->assertTrue($rules->isRetakeRequired(0));
        $this->assertTrue($rules->isRetakeRequired(7.5));
        $this->assertFalse($rules->isRetakeRequired(7.51));
    }
}
