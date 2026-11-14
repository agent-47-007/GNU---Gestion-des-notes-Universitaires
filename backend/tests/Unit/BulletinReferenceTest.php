<?php

namespace Tests\Unit;

use App\Services\BulletinReference;
use PHPUnit\Framework\TestCase;

class BulletinReferenceTest extends TestCase
{
    public function test_reference_is_stable_and_safe_for_a_file_name(): void
    {
        $reference = (new BulletinReference)->make(
            '2026/2027',
            'INF-L3-2026-2027',
            '21T/2355',
            'ANNUELLE',
            2,
        );

        $this->assertSame('UY1-RELEVE-2026-2027-INF-L3-2026-2027-21T-2355-ANNUELLE-V2', $reference);
        $this->assertMatchesRegularExpression('/^[A-Za-z0-9-]+$/', $reference);
    }
}
