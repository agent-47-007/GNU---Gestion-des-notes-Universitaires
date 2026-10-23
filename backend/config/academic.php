<?php

return [
    'local_test_account_portal' => env('GNU_ENABLE_LOCAL_TEST_ACCOUNT_PORTAL', false),
    'evaluation_total_weight' => 100,
    'mark_scale' => 20,
    'passing_mark' => 10,
    'mark_rounding_decimals' => 2,
    'admission_minimum_mgp' => 2.00,
    'admission_minimum_ue' => 35.00,
    'retake_minimum_mark' => 5,
    'retake_maximum_inclusive' => 10,
    'retake_max_sessions' => 1,
    'publication_admin_logins' => array_values(array_filter(array_map(
        static fn (string $login): string => mb_strtolower(trim($login)),
        explode(',', (string) env('GNU_PUBLICATION_ADMIN_LOGINS', '')),
    ))),
];
