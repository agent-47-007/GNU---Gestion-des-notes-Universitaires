<?php

use App\Models\Utilisateur;

return [
    'defaults' => ['guard' => 'web'],
    'guards' => ['web' => ['driver' => 'session', 'provider' => 'utilisateurs']],
    'providers' => ['utilisateurs' => ['driver' => 'eloquent', 'model' => Utilisateur::class]],
    // Hash public sans compte associé, pour effectuer aussi une vérification si le login est inconnu.
    'dummy_password_hash' => '$2y$12$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2uheWG/igi.',
];
