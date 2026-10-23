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
        'pgsql_setup' => [
            'driver' => 'pgsql',
            'host' => env('GNU_LOCAL_SETUP_DB_HOST', '127.0.0.1'),
            'port' => env('GNU_LOCAL_SETUP_DB_PORT', env('DB_PORT', '5435')),
            'database' => env('GNU_LOCAL_SETUP_DB_DATABASE', env('DB_DATABASE', 'gnu_notes')),
            'username' => env('GNU_LOCAL_SETUP_DB_USERNAME', env('DB_USERNAME', '')),
            'password' => env('GNU_LOCAL_SETUP_DB_PASSWORD', ''),
            'charset' => 'utf8',
            'prefix' => '',
            'prefix_indexes' => true,
            'search_path' => 'gnu,gnu_auth,pg_catalog',
            'sslmode' => env('GNU_LOCAL_SETUP_DB_SSLMODE', 'disable'),
            'timezone' => 'UTC',
        ],
    ],
    'migrations' => ['table' => 'migrations', 'update_date_on_publish' => true],
];
