<?php

return [
    'stateful' => [],
    'guard' => [],
    'expiration' => max(1, (int) env('SANCTUM_EXPIRATION', 480)),
    'token_prefix' => 'gnu_',
    'middleware' => [],
];
