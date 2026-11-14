<?php

namespace App\Console\Commands;

use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;
use Symfony\Component\Process\Process;
use Throwable;

#[Signature('gnu:backup {--connection=pgsql : Connexion PostgreSQL à sauvegarder}')]
#[Description('Crée une sauvegarde PostgreSQL privée et vérifie son empreinte SHA-256')]
class BackupGnuDatabase extends Command
{
    public function handle(): int
    {
        $connection = config('database.connections.'.$this->option('connection'));
        if (! is_array($connection) || ($connection['driver'] ?? null) !== 'pgsql') {
            $this->components->error('La sauvegarde GNU exige une connexion PostgreSQL valide.');

            return self::FAILURE;
        }

        $database = (string) ($connection['database'] ?? '');
        if ($database === '') {
            $this->components->error('La base PostgreSQL cible n’est pas configurée.');

            return self::FAILURE;
        }

        $directory = storage_path('app/private/backups');
        if (! is_dir($directory) && ! mkdir($directory, 0700, true) && ! is_dir($directory)) {
            $this->components->error('Impossible de créer le dossier privé des sauvegardes.');

            return self::FAILURE;
        }
        @chmod($directory, 0700);

        $safeDatabase = preg_replace('/[^A-Za-z0-9_-]+/', '-', $database) ?: 'gnu';
        $filename = sprintf('%s-%s.dump', $safeDatabase, now()->format('Ymd-His-u'));
        $path = $directory.DIRECTORY_SEPARATOR.$filename;
        $process = new Process([
            'pg_dump', '--format=custom', '--no-owner', '--no-acl', '--no-password',
            '--host='.(string) ($connection['host'] ?? '127.0.0.1'),
            '--port='.(string) ($connection['port'] ?? '5432'),
            '--username='.(string) ($connection['username'] ?? ''),
            '--file='.$path,
            $database,
        ], base_path(), $this->postgresEnvironment($connection), timeout: 1800);
        $previousUmask = umask(0077);
        try {
            $process->run();
        } catch (Throwable $exception) {
            @unlink($path);
            $this->components->error('Impossible de lancer pg_dump : '.$exception->getMessage());

            return self::FAILURE;
        } finally {
            umask($previousUmask);
        }
        if (! $process->isSuccessful()) {
            @unlink($path);
            $this->components->error('Échec de pg_dump : '.$process->getErrorOutput());

            return self::FAILURE;
        }

        chmod($path, 0600);
        $hash = hash_file('sha256', $path);
        if (! is_string($hash)) {
            @unlink($path);
            $this->components->error('La sauvegarde créée n’a pas pu être vérifiée.');

            return self::FAILURE;
        }
        if (file_put_contents($path.'.sha256', $hash.'  '.$filename.PHP_EOL, LOCK_EX) === false) {
            @unlink($path);
            $this->components->error('La sauvegarde existe, mais son empreinte n’a pas pu être écrite.');

            return self::FAILURE;
        }
        chmod($path.'.sha256', 0600);
        $this->components->info('Sauvegarde vérifiée : '.$path);
        $this->line('SHA-256 : '.$hash);

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
