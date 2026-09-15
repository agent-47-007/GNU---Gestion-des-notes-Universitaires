<?php

namespace App\Providers;

use App\Models\PersonalAccessToken;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;
use Laravel\Sanctum\Sanctum;

class AppServiceProvider extends ServiceProvider
{
    public function boot(): void
    {
        Sanctum::usePersonalAccessTokenModel(PersonalAccessToken::class);

        RateLimiter::for('login', function (Request $request): array {
            $login = $request->input('login');
            $key = hash('sha256', is_string($login) ? mb_strtolower(trim($login)) : '');

            return [Limit::perMinute(30)->by('ip:'.$request->ip()), Limit::perMinute(5)->by('login:'.$key.':'.$request->ip())];
        });
        RateLimiter::for('api', fn (Request $request) => Limit::perMinute(120)->by((string) $request->user()->id));
        RateLimiter::for('password', fn (Request $request) => Limit::perMinute(5)->by((string) $request->user()->id));
    }
}
