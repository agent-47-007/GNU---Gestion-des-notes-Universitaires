<?php

namespace App\Services;

use App\Models\Utilisateur;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

class SystemAdministratorAccess
{
    public function isAdministrator(Utilisateur $user): bool
    {
        if ($user->role?->value !== 'AGENT' || ! $user->actif) {
            return false;
        }

        if ($this->isConfiguredLogin((string) $user->login)) {
            return true;
        }

        return DB::table('gnu.agent_administrateur_systeme')
            ->where('agent_id', $user->getKey())
            ->exists();
    }

    public function isConfiguredLogin(string $login): bool
    {
        return in_array(
            mb_strtolower(trim($login)),
            config('academic.publication_admin_logins', []),
            true,
        );
    }

    public function hasAdministratorGrant(int $userId): bool
    {
        return DB::table('gnu.agent_administrateur_systeme')
            ->where('agent_id', $userId)
            ->exists();
    }

    public function activeAdministratorCount(): int
    {
        $configuredLogins = config('academic.publication_admin_logins', []);
        $configuredIds = $configuredLogins === []
            ? collect()
            : DB::table('gnu.utilisateur')
                ->where('role', 'AGENT')
                ->where('actif', true)
                ->whereIn(DB::raw('lower(login)'), $configuredLogins)
                ->pluck('id');
        $databaseIds = DB::table('gnu.agent_administrateur_systeme as aa')
            ->join('gnu.utilisateur as u', 'u.id', '=', 'aa.agent_id')
            ->where('u.role', 'AGENT')
            ->where('u.actif', true)
            ->pluck('u.id');

        return $configuredIds->concat($databaseIds)->unique()->count();
    }

    /**
     * @return Collection<int, object>
     */
    public function lockAdministratorGrants(): Collection
    {
        return DB::table('gnu.agent_administrateur_systeme')
            ->orderBy('agent_id')
            ->lockForUpdate()
            ->get();
    }
}
