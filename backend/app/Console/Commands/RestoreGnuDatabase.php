<?php

namespace App\Console\Commands;

use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;
use Symfony\Component\Process\Process;
use Throwable;

#[Signature('gnu:restore {backup : Nom du fichier .dump dans storage/app/private/backups} {--connection=pgsql : Connexion PostgreSQL cible} {--apply : Autorise la restauration destructive} {--confirm-database= : Doit correspondre exactement au nom de la base cible}')]
#[Description('Restaure une sauvegarde vérifiée après confirmation explicite de la base cible')]
class RestoreGnuDatabase extends Command
{
    public function handle(): int
    {
        $connection = config('database.connections.'.$this->option('connection'));
        if (! is_array($connection) || ($connection['driver'] ?? null) !== 'pgsql') {
            $this->components->error('La restauration GNU exige une connexion PostgreSQL valide.');

            return self::FAILURE;
        }

        $database = (string) ($connection['database'] ?? '');
        if (! app()->environment(['local', 'testing']) || ! $this->option('apply') || $database === '' || $this->option('confirm-database') !== $database) {
            $this->components->error('Restauration bloquée : utilisez APP_ENV local/testing, --apply et --confirm-database='.$database.'. Cette opération remplace les objets et données de la base cible.');

            return self::FAILURE;
        }

        $filename = basename((string) $this->argument('backup'));
        $directory = realpath(storage_path('app/private/backups'));
        $path = $directory === false ? false : realpath($directory.DIRECTORY_SEPARATOR.$filename);
        if ($path === false || ! str_ends_with($filename, '.dump') || ! str_starts_with($path, $directory.DIRECTORY_SEPARATOR) || ! is_file($path)) {
            $this->components->error('Fichier de sauvegarde absent ou hors du dossier privé autorisé.');

            return self::FAILURE;
        }

        $checksumContent = is_file($path.'.sha256') ? file_get_contents($path.'.sha256') : false;
        $expectedHash = is_string($checksumContent) ? strtok(trim($checksumContent), " \t") : false;
        $actualHash = hash_file('sha256', $path);
        if (! is_string($expectedHash) || ! is_string($actualHash) || ! hash_equals($expectedHash, $actualHash)) {
            $this->components->error('Empreinte SHA-256 absente ou invalide; restauration refusée.');

            return self::FAILURE;
        }

        $process = new Process([
            'pg_restore', '--exit-on-error', '--clean', '--if-exists', '--no-owner', '--no-acl', '--single-transaction', '--no-password',
            '--host='.(string) ($connection['host'] ?? '127.0.0.1'),
            '--port='.(string) ($connection['port'] ?? '5432'),
            '--username='.(string) ($connection['username'] ?? ''),
            '--dbname='.$database,
            $path,
        ], base_path(), $this->postgresEnvironment($connection), timeout: 3600);
        try {
            $process->run();
        } catch (Throwable $exception) {
            $this->components->error('Impossible de lancer pg_restore : '.$exception->getMessage());

            return self::FAILURE;
        }
        if (! $process->isSuccessful()) {
            $this->components->error('Échec de pg_restore : '.$process->getErrorOutput());

            return self::FAILURE;
        }

        $this->components->info('Restauration terminée dans la base confirmée : '.$database);

        return self::SUCCESS;
    }

    /** @param array<string, mixed> $connection
     * @return array<string, string>
     */
    private function postgresEnvironment(array $connection): array
    {
        $environment = [];
        if (isset($connection['password']) && $connection['password'] !== '') {
            $environment['PGPASSWORD'] = (string) $connection['password'];
        }
        if (isset($connection['sslmode']) && $connection['sslmode'] !== '') {
            $environment['PGSSLMODE'] = (string) $connection['sslmode'];
        }

        return $environment;
    }
}
