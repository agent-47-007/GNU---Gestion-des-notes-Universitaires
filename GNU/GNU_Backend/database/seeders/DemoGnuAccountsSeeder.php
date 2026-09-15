<?php

namespace Database\Seeders;

use App\Enums\Role;
use App\Models\Enseignant;
use App\Models\Etudiant;
use App\Models\Utilisateur;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DemoGnuAccountsSeeder extends Seeder
{
    public function run(): void
    {
        $accounts = [
            [
                'code_utilisateur' => 'CODE-ENS-4182',
                'login' => 'ENS-4182-INFO',
                'role' => Role::Enseignant,
                'nom' => 'TITULAIRE',
                'prenom' => 'Enseignant',
                'profile' => [
                    'type' => 'enseignant',
                    'eid' => 'ENS-4182-INFO',
                    'fonction_enseignant' => 'Titulaire',
                ],
            ],
            [
                'code_utilisateur' => 'CODE-AGENT-CELLULE',
                'login' => 'ADM-8842-CELLULE',
                'role' => Role::Agent,
                'nom' => 'CELLULE',
                'prenom' => 'Agent',
                'profile' => [
                    'type' => 'agent',
                ],
            ],
            [
                'code_utilisateur' => 'CODE-ETU-21T2355',
                'login' => '21T2355',
                'role' => Role::Etudiant,
                'nom' => 'ETUDIANT',
                'prenom' => 'Test',
                'profile' => [
                    'type' => 'etudiant',
                    'matricule' => 'MAT-21T2355',
                ],
            ],
        ];

        foreach ($accounts as $account) {
            $user = Utilisateur::query()->where('login', $account['login'])->first();

            if (! $user) {
                $user = Utilisateur::query()->create([
                    'code_utilisateur' => $account['code_utilisateur'],
                    'login' => $account['login'],
                    'mot_de_passe_hash' => Hash::make('12345'),
                    'role' => $account['role']->value,
                    'actif' => true,
                    'nom' => $account['nom'],
                    'prenom' => $account['prenom'],
                ]);
            } else {
                $user->update([
                    'code_utilisateur' => $account['code_utilisateur'],
                    'role' => $account['role']->value,
                    'actif' => true,
                    'nom' => $account['nom'],
                    'prenom' => $account['prenom'],
                    'mot_de_passe_hash' => Hash::make('12345'),
                ]);
            }

            if ($account['profile']['type'] === 'enseignant') {
                $user->enseignant()->updateOrCreate(
                    ['utilisateur_id' => $user->id],
                    ['eid' => $account['profile']['eid'], 'fonction_enseignant' => $account['profile']['fonction_enseignant']]
                );
            }

            if ($account['profile']['type'] === 'etudiant') {
                $user->etudiant()->updateOrCreate(
                    ['utilisateur_id' => $user->id],
                    ['matricule' => $account['profile']['matricule']]
                );
            }
        }
    }
}
