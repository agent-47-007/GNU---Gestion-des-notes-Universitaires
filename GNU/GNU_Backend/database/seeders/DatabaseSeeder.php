<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        $this->command?->info('Aucun compte de démonstration. Initialiser le premier agent avec gnu:create-agent.');
    }
}
