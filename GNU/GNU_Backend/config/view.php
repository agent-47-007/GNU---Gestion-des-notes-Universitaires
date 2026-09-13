<?php

return [
    'paths' => [
        base_path('../GNU_Frontend/web/resources/views'),
    ],

    'compiled' => env(
        'VIEW_COMPILED_PATH',
        realpath(storage_path('framework/views')),
    ),
];
