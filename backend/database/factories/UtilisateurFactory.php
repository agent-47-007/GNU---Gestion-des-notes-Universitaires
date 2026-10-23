<?php

namespace Database\Factories;

use App\Enums\Role;
use App\Models\Utilisateur;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Facades\Hash;

class UtilisateurFactory extends Factory
{
    protected $model = Utilisateur::class;

    public function definition(): array
    {
        return [
            'code_utilisateur' => fake()->unique()->bothify('TEST-????????####'),
            'login' => fake()->unique()->userName(),
            'mot_de_passe_hash' => Hash::make('TestSecret12345'),
            'role' => Role::Agent,
            'actif' => true,
            'nom' => fake()->lastName(),
            'prenom' => fake()->firstName(),
        ];
    }

    public function etudiant(): static
    {
        return $this->state(['role' => Role::Etudiant])->afterCreating(fn (Utilisateur $user) => $user->etudiant()->create(['matricule' => fake()->unique()->bothify('MAT-????????')]));
    }

    public function enseignant(): static
    {
        return $this->state(['role' => Role::Enseignant])->afterCreating(fn (Utilisateur $user) => $user->enseignant()->create(['eid' => fake()->unique()->bothify('ENS-????????')]));
    }

    public function agent(): static
    {
        return $this->state(['role' => Role::Agent]);
    }
}
