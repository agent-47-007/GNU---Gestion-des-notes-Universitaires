<?php

namespace App\Console\Commands;

use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Throwable;

#[Signature('gnu:import-account-requests {csv : Fichier CSV UTF-8 avec séparateur virgule} {--role= : ETUDIANT ou ENSEIGNANT} {--department=INFO : Code du département} {--connection=pgsql : Connexion Laravel cible} {--apply : Créer les demandes après confirmation}')]
#[Description('Importe des demandes de comptes étudiants ou enseignants, soumises à validation système')]
class ImportAccountRequests extends Command
{
    public function handle(): int
    {
        $role = strtoupper(trim((string) $this->option('role')));
        if (! in_array($role, ['ETUDIANT', 'ENSEIGNANT'], true)) {
            $this->components->error('Indiquez --role=ETUDIANT ou --role=ENSEIGNANT.');

            return self::FAILURE;
        }

        $path = (string) $this->argument('csv');
        if (! is_file($path) || ! is_readable($path)) {
            $this->components->error("Fichier CSV illisible : {$path}");

            return self::FAILURE;
        }

        try {
            $rows = $this->readCsv($path, $role);
        } catch (Throwable $error) {
            $this->components->error($error->getMessage());

            return self::FAILURE;
        }
        if ($rows === []) {
            $this->components->warn('Aucune ligne exploitable dans le fichier.');

            return self::SUCCESS;
        }

        $connectionName = (string) $this->option('connection');
        $connection = DB::connection($connectionName);
        $database = (string) $connection->getDatabaseName();
        $department = $connection->table('gnu.departement')
            ->whereRaw('upper(code_de) = ?', [strtoupper(trim((string) $this->option('department')))])
            ->first(['id', 'code_de', 'nom_depart']);
        if ($department === null) {
            $this->components->error('Département introuvable dans la base cible.');

            return self::FAILURE;
        }

        $errors = [];
        $seenProfiles = [];
        $seenLogins = [];
        $seenEmails = [];
        foreach ($rows as $index => $row) {
            $line = $index + 2;
            $profile = strtoupper($row['identifiant_profil']);
            $login = strtolower($row['login']);
            $email = $row['courriel'] === '' ? null : strtolower($row['courriel']);
            if (isset($seenProfiles[$profile])) {
                $errors[] = "Ligne {$line} : profil en doublon dans le CSV.";
            }
            $seenProfiles[$profile] = true;
            if (isset($seenLogins[$login])) {
                $errors[] = "Ligne {$line} : login en doublon dans le CSV.";
            }
            $seenLogins[$login] = true;
            if ($email !== null) {
                if (isset($seenEmails[$email])) {
                    $errors[] = "Ligne {$line} : courriel en doublon dans le CSV.";
                }
                $seenEmails[$email] = true;
            }
            $code = ($role === 'ETUDIANT' ? 'ETU-' : 'ENS-').$profile;
            if ($connection->table('gnu.utilisateur')->whereRaw('lower(login) = ?', [$login])->exists()
                || $connection->table('gnu.demande_compte')->where('statut', 'EN_ATTENTE')->whereRaw('lower(login) = ?', [$login])->exists()) {
                $errors[] = "Ligne {$line} : le login {$login} existe déjà ou a une demande en attente.";
            }
            if ($connection->table('gnu.utilisateur')->whereRaw('upper(code_utilisateur) = ?', [$code])->exists()) {
                $errors[] = "Ligne {$line} : le code profil {$code} existe déjà.";
            }
            $profileExists = $role === 'ETUDIANT'
                ? $connection->table('gnu.etudiant')->whereRaw('upper(matricule) = ?', [$profile])->exists()
                : $connection->table('gnu.enseignant')->whereRaw('upper(eid) = ?', [$profile])->exists();
            if ($profileExists || $connection->table('gnu.demande_compte')->where('role', $role)->whereRaw('upper(identifiant_profil) = ?', [$profile])->whereIn('statut', ['EN_ATTENTE', 'APPROUVEE'])->exists()) {
                $errors[] = "Ligne {$line} : le profil {$profile} existe déjà ou a une demande à traiter.";
            }
            if ($email !== null && ($connection->table('gnu.utilisateur')->whereRaw('lower(courriel) = ?', [$email])->exists()
                || $connection->table('gnu.demande_compte')->whereRaw('lower(courriel) = ?', [$email])->where('statut', 'EN_ATTENTE')->exists())) {
                $errors[] = "Ligne {$line} : le courriel {$email} est déjà utilisé.";
            }
        }

        $this->table(['Rôle', 'Demandes', 'Département', 'Base'], [[$role, count($rows), $department->code_de.' · '.$department->nom_depart, $database]]);
        if ($errors !== []) {
            $this->components->error('Aucune demande importée : corrigez les erreurs suivantes puis relancez.');
            foreach (array_slice($errors, 0, 30) as $error) {
                $this->line('• '.$error);
            }
            if (count($errors) > 30) {
                $this->line('… '.(count($errors) - 30).' autre(s) erreur(s).');
            }

            return self::FAILURE;
        }

        if (! $this->option('apply')) {
            $this->components->info('Prévisualisation uniquement. Relancez avec --apply pour créer les demandes en attente.');

            return self::SUCCESS;
        }

        if (! $this->confirm("Les demandes seront créées dans « {$database} » avec le statut EN_ATTENTE. Continuer ?")) {
            return self::SUCCESS;
        }
        $password = (string) $this->secret('Mot de passe initial commun (12 caractères minimum)');
        $confirmation = (string) $this->secret('Confirmer le mot de passe initial');
        if (mb_strlen($password) < 12 || ! hash_equals($password, $confirmation)) {
            $this->components->error('Mot de passe trop court ou confirmation différente. Aucune demande créée.');

            return self::FAILURE;
        }

        try {
            $connection->transaction(function () use ($connection, $rows, $role, $department, $password): void {
                $now = now();
                foreach ($rows as $row) {
                    $profile = strtoupper($row['identifiant_profil']);
                    $connection->table('gnu.demande_compte')->insert([
                        'role' => $role,
                        'login' => $row['login'],
                        'code_utilisateur' => ($role === 'ETUDIANT' ? 'ETU-' : 'ENS-').$profile,
                        'nom' => $row['nom'],
                        'prenom' => $row['prenom'],
                        'courriel' => $row['courriel'] === '' ? null : strtolower($row['courriel']),
                        'identifiant_profil' => $profile,
                        'departement_id' => $department->id,
                        'filiere_id' => null,
                        'specialite_id' => null,
                        'reference_identite' => $row['reference_identite'],
                        'mot_de_passe_hash' => Hash::make($password),
                        'statut' => 'EN_ATTENTE',
                        'created_at' => $now,
                        'updated_at' => $now,
                    ]);
                }
            });
        } catch (Throwable $error) {
            report($error);
            $this->components->error('Échec de l’import ; la transaction a été annulée. Consultez le journal Laravel.');

            return self::FAILURE;
        }

        $this->components->info(count($rows).' demande(s) créée(s) en attente. Aucun compte n’a encore été activé.');
        $this->warn('Après vérification et approbation par l’administrateur système, affectez les enseignants aux UE/EC depuis « Comptes & affectations ».');

        return self::SUCCESS;
    }

    /** @return list<array{login:string,identifiant_profil:string,nom:string,prenom:string,courriel:string,reference_identite:string}> */
    private function readCsv(string $path, string $role): array
    {
        $handle = fopen($path, 'rb');
        if ($handle === false) {
            throw new \RuntimeException('Impossible d’ouvrir le fichier CSV.');
        }
        try {
            $header = fgetcsv($handle, 0, ',');
            if ($header === false) {
                return [];
            }
            $header[0] = preg_replace('/^\xEF\xBB\xBF/', '', (string) $header[0]);
            $header = array_map(static fn ($value): string => strtolower(trim((string) $value)), $header);
            $idColumn = $role === 'ETUDIANT' ? 'matricule' : 'eid';
            $required = [$idColumn, 'nom', 'prenom', 'courriel', 'reference_identite'];
            $missing = array_diff($required, $header);
            if ($missing !== []) {
                throw new \RuntimeException('Colonnes CSV manquantes : '.implode(', ', $missing).'.');
            }
            $positions = array_flip($header);
            $rows = [];
            $line = 1;
            while (($values = fgetcsv($handle, 0, ',')) !== false) {
                $line++;
                if ($values === [null] || (count($values) === 1 && trim((string) $values[0]) === '')) {
                    continue;
                }
                $get = static fn (string $column): string => trim((string) ($values[$positions[$column]] ?? ''));
                $profile = strtoupper($get($idColumn));
                $nom = $get('nom');
                $prenom = $get('prenom');
                $email = $get('courriel');
                $identity = $get('reference_identite');
                if (! preg_match('/^[A-Z0-9-]{1,59}$/', $profile) || $nom === '' || $prenom === '' || mb_strlen($nom) > 120 || mb_strlen($prenom) > 120 || mb_strlen($identity) < 4 || mb_strlen($identity) > 160) {
                    throw new \RuntimeException("Ligne {$line} : identifiant, nom, prénom ou référence d’identité invalide/incomplet.");
                }
                if ($email !== '' && filter_var($email, FILTER_VALIDATE_EMAIL) === false) {
                    throw new \RuntimeException("Ligne {$line} : adresse courriel invalide.");
                }
                $rows[] = [
                    'login' => $profile,
                    'identifiant_profil' => $profile,
                    'nom' => $nom,
                    'prenom' => $prenom,
                    'courriel' => $email,
                    'reference_identite' => $identity,
                ];
            }

            return $rows;
        } finally {
            fclose($handle);
        }
    }
}
