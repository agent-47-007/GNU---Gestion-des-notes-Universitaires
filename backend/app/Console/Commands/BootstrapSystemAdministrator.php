<?php

namespace App\Console\Commands;

use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

#[Signature('gnu:bootstrap-system-admin')]
#[Description('Crée le premier compte Agent administrateur système GNU')]
class BootstrapSystemAdministrator extends Command
{
    public function handle(): int
    {
        $database = (string) config('database.connections.pgsql_setup.database');
        if (! $this->confirm("Cette opération va créer le premier administrateur dans la base « {$database} ». Confirmez-vous la base cible ?")) {
            return self::FAILURE;
        }

        $connection = DB::connection('pgsql_setup');
        $marker = $connection->selectOne("SELECT to_regclass('gnu.agent_administrateur_systeme') AS table_name");
        if (empty($marker?->table_name)) {
            $this->components->error('La table administrateur système est absente. Appliquez d’abord les migrations GNU sur cette base.');

            return self::FAILURE;
        }
        if ($connection->table('gnu.agent_administrateur_systeme')->exists()) {
            $this->components->error('Un administrateur système est déjà enregistré. Cette commande est à usage unique.');

            return self::FAILURE;
        }

        $configuredLogins = config('academic.publication_admin_logins', []);
        if ($configuredLogins !== [] && $connection->table('gnu.utilisateur')->where('role', 'AGENT')->where('actif', true)
            ->whereIn(DB::raw('lower(login)'), $configuredLogins)->exists()) {
            $this->components->error('Un compte Agent administrateur est déjà configuré. Modifiez GNU_PUBLICATION_ADMIN_LOGINS au lieu d’en créer un autre.');

            return self::FAILURE;
        }

        $departments = $connection->table('gnu.departement')->orderBy('code_de')->get(['id', 'code_de', 'nom_depart']);
        if ($departments->isEmpty()) {
            $this->components->error('Aucun département n’existe. Créez d’abord la structure universitaire.');

            return self::FAILURE;
        }
        $this->table(['ID', 'Code', 'Département'], $departments->map(static fn (object $row): array => [$row->id, $row->code_de, $row->nom_depart])->all());

        $login = mb_strtolower(trim((string) $this->ask('Login administrateur')));
        $profile = mb_strtoupper(trim((string) $this->ask('Identifiant Agent')));
        $lastName = trim((string) $this->ask('Nom'));
        $firstName = trim((string) $this->ask('Prénom'));
        $emailInput = trim((string) $this->ask('Courriel (facultatif)', ''));
        $departmentId = filter_var($this->ask('ID du département'), FILTER_VALIDATE_INT);

        if (! preg_match('/^[a-z0-9._-]{1,64}$/', $login)
            || ! preg_match('/^[A-Z0-9-]{1,60}$/', $profile)
            || $lastName === '' || $firstName === ''
            || $departmentId === false
            || ! $departments->contains(static fn (object $row): bool => (int) $row->id === $departmentId)) {
            $this->components->error('Les informations fournies sont invalides; aucun compte n’a été créé.');

            return self::FAILURE;
        }
        if ($emailInput !== '' && filter_var($emailInput, FILTER_VALIDATE_EMAIL) === false) {
            $this->components->error('Le courriel fourni est invalide; aucun compte n’a été créé.');

            return self::FAILURE;
        }

        $password = (string) $this->secret('Mot de passe (12 caractères minimum)');
        $confirmation = (string) $this->secret('Confirmer le mot de passe');
        if (mb_strlen($password) < 12 || ! hash_equals($password, $confirmation)) {
            $this->components->error('Le mot de passe est trop court ou les deux saisies diffèrent; aucun compte n’a été créé.');

            return self::FAILURE;
        }

        $code = 'AGT-'.$profile;
        if ($connection->table('gnu.utilisateur')->whereRaw('lower(login) = ?', [$login])->exists()
            || $connection->table('gnu.utilisateur')->whereRaw('upper(code_utilisateur) = ?', [$code])->exists()) {
            $this->components->error('Le login ou l’identifiant Agent existe déjà; aucun compte n’a été créé.');

            return self::FAILURE;
        }
        if ($emailInput !== '' && $connection->table('gnu.utilisateur')->whereRaw('lower(courriel) = ?', [mb_strtolower($emailInput)])->exists()) {
            $this->components->error('Cette adresse courriel est déjà rattachée à un compte GNU. Relancez la commande avec une autre adresse ou laissez le champ vide.');

            return self::FAILURE;
        }

        $userId = $connection->transaction(function () use ($connection, $code, $login, $password, $lastName, $firstName, $emailInput, $departmentId): int {
            $connection->select("SELECT set_config('gnu.motif', ?, true)", ['Amorçage initial de l’administrateur système']);
            $id = $connection->table('gnu.utilisateur')->insertGetId([
                'code_utilisateur' => $code,
                'login' => $login,
                'mot_de_passe_hash' => Hash::make($password),
                'role' => 'AGENT',
                'actif' => true,
                'nom' => $lastName,
                'prenom' => $firstName,
                'courriel' => $emailInput === '' ? null : mb_strtolower($emailInput),
                'created_at' => now(),
                'updated_at' => now(),
            ], 'id');
            $connection->table('gnu.agent_departement')->insert([
                'agent_id' => $id,
                'departement_id' => $departmentId,
                'created_at' => now(),
            ]);
            $connection->table('gnu.agent_administrateur_systeme')->insert([
                'agent_id' => $id,
                'created_at' => now(),
            ]);

            return (int) $id;
        });

        $this->components->info("Compte Agent administrateur créé (ID {$userId}) dans « {$database} ».");
        $this->line('Le droit administrateur est enregistré en base; aucune modification de GNU_PUBLICATION_ADMIN_LOGINS n’est requise.');
        $this->warn('Le mot de passe n’a pas été affiché. Conservez-le en lieu sûr. Cette commande ne doit pas être relancée sur une base avec administrateur système.');

        return self::SUCCESS;
    }
}
