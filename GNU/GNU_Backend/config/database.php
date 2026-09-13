<?php

return [
    'default' => 'pgsql',
    'connections' => [
        'pgsql' => [
            'driver' => 'pgsql',
            'host' => env('DB_HOST', '127.0.0.1'),
            'port' => env('DB_PORT', '5435'),
            'database' => env('DB_DATABASE', 'gnu_notes'),
            'username' => env('DB_USERNAME', 'gnu_app'),
            'password' => env('DB_PASSWORD', ''),
            'charset' => 'utf8',
            'prefix' => '',
            'prefix_indexes' => true,
            'search_path' => 'gnu,gnu_auth,pg_catalog',
            'sslmode' => env('DB_SSLMODE', 'prefer'),
            'timezone' => 'UTC',
        ],
    ],
    'migrations' => ['table' => 'gnu_auth.migrations', 'update_date_on_publish' => true],
];
