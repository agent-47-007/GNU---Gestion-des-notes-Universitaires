<?php

namespace App\Models;

use App\Enums\Role;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Laravel\Sanctum\HasApiTokens;

class Utilisateur extends Authenticatable
{
    use HasApiTokens, HasFactory;

    protected $table = 'gnu.utilisateur';

    protected $fillable = ['code_utilisateur', 'login', 'mot_de_passe_hash', 'role', 'actif', 'nom', 'prenom'];

    protected $hidden = ['mot_de_passe_hash'];

    protected $authPasswordName = 'mot_de_passe_hash';

    protected $rememberTokenName = null;

    protected function casts(): array
    {
        return ['role' => Role::class, 'actif' => 'boolean'];
    }

    public function etudiant(): HasOne
    {
        return $this->hasOne(Etudiant::class, 'utilisateur_id');
    }

    public function enseignant(): HasOne
    {
        return $this->hasOne(Enseignant::class, 'utilisateur_id');
    }

    public function hasCompleteProfile(): bool
    {
        return match ($this->role) {
            Role::Etudiant => $this->etudiant !== null,
            Role::Enseignant => $this->enseignant !== null,
            Role::Agent => true,
        };
    }
}
