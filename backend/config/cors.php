<?php

$localOrigins = 'http://127.0.0.1:8768,http://localhost:8768,http://127.0.0.1:8783,http://localhost:8783,http://127.0.0.1:8782,http://localhost:8782,http://127.0.0.1:8780,http://localhost:8780';
$defaultOrigins = env('APP_ENV', 'production') === 'local' ? $localOrigins : '';

return [
    'paths' => ['api/*'],
    'allowed_methods' => ['GET', 'POST', 'PUT', 'PATCH', 'OPTIONS'],
    'allowed_origins' => array_values(array_filter(array_map('trim', explode(',', env('CORS_ALLOWED_ORIGINS', $defaultOrigins))))),
    'allowed_origins_patterns' => [],
    'allowed_headers' => ['Accept', 'Authorization', 'Content-Type'],
    'exposed_headers' => ['Retry-After'],
    'max_age' => 600,
    'supports_credentials' => false,
];
