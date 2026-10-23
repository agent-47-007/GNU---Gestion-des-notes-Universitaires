<?php

namespace App\Providers;

use App\Models\PersonalAccessToken;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;
use Laravel\Sanctum\Sanctum;
use RuntimeException;

class AppServiceProvider extends ServiceProvider
{
    public function boot(): void
    {
        $this->assertProductionConfiguration();

        Sanctum::usePersonalAccessTokenModel(PersonalAccessToken::class);

        RateLimiter::for('login', function (Request $request): array {
            $login = $request->input('login');
            $key = hash('sha256', is_string($login) ? mb_strtolower(trim($login)) : '');

            return [Limit::perMinute(30)->by('ip:'.$request->ip()), Limit::perMinute(5)->by('login:'.$key.':'.$request->ip())];
        });
        RateLimiter::for('api', fn (Request $request) => Limit::perMinute(120)->by((string) $request->user()->id));
        RateLimiter::for('password', fn (Request $request) => Limit::perMinute(5)->by((string) $request->user()->id));
    }

    private function assertProductionConfiguration(): void
    {
        if (! app()->isProduction()) {
            return;
        }

        $required = [
            'app.key' => config('app.key'),
            'app.url' => config('app.url'),
            'database.connections.pgsql.host' => config('database.connections.pgsql.host'),
            'database.connections.pgsql.database' => config('database.connections.pgsql.database'),
            'database.connections.pgsql.username' => config('database.connections.pgsql.username'),
            'database.connections.pgsql.password' => config('database.connections.pgsql.password'),
        ];

        foreach ($required as $key => $value) {
            if (! is_string($value) || trim($value) === '') {
                throw new RuntimeException("Configuration de production requise : {$key}.");
            }
        }

        if (strlen((string) config('app.key')) < 32) {
            throw new RuntimeException('APP_KEY doit contenir une clé Laravel valide en production.');
        }

        $databaseHost = strtolower((string) config('database.connections.pgsql.host'));
        if (in_array($databaseHost, ['localhost', '127.0.0.1', '::1'], true)) {
            throw new RuntimeException('DB_HOST ne peut pas pointer vers localhost en production.');
        }

        $applicationUrl = parse_url((string) config('app.url'));
        $applicationHost = strtolower((string) ($applicationUrl['host'] ?? ''));
        if (($applicationUrl['scheme'] ?? null) !== 'https' || $applicationHost === '' || in_array($applicationHost, ['localhost', '127.0.0.1', '::1'], true)) {
            throw new RuntimeException('APP_URL doit être une URL HTTPS valide en production.');
        }

        if (! in_array(config('database.connections.pgsql.sslmode'), ['verify-ca', 'verify-full'], true)) {
            throw new RuntimeException('DB_SSLMODE doit vérifier le certificat PostgreSQL en production.');
        }

        $allowedOrigins = config('cors.allowed_origins', []);
        if ($allowedOrigins === []) {
            throw new RuntimeException('CORS_ALLOWED_ORIGINS doit autoriser explicitement l’origine Web en production.');
        }

        foreach ($allowedOrigins as $origin) {
            $parsedOrigin = parse_url($origin);
            if (! is_array($parsedOrigin)) {
                throw new RuntimeException('Chaque origine CORS de production doit être une origine HTTPS valide.');
            }

            $originHost = strtolower((string) ($parsedOrigin['host'] ?? ''));
            if (($parsedOrigin['scheme'] ?? null) !== 'https' || $originHost === '' || str_contains($originHost, '*') || in_array($originHost, ['localhost', '127.0.0.1', '::1'], true) || ! in_array($parsedOrigin['path'] ?? '', ['', '/'], true) || isset($parsedOrigin['user']) || isset($parsedOrigin['pass']) || isset($parsedOrigin['query']) || isset($parsedOrigin['fragment'])) {
                throw new RuntimeException('Chaque origine CORS de production doit être une origine HTTPS valide.');
            }
        }
    }
}
