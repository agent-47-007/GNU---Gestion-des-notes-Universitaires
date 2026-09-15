<?php

namespace App\Http\Resources;

use App\Enums\Role;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class UtilisateurResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $this->resource->loadMissing(['etudiant', 'enseignant']);

        return [
            'id' => $this->id,
            'code_utilisateur' => $this->code_utilisateur,
            'login' => $this->login,
            'role' => $this->role->value,
            'actif' => $this->actif,
            'nom' => $this->nom,
            'prenom' => $this->prenom,
            'profil' => match ($this->role) {
                Role::Etudiant => $this->etudiant ? ['id' => $this->etudiant->id, 'matricule' => $this->etudiant->matricule] : null,
                Role::Enseignant => $this->enseignant ? [
                    'id' => $this->enseignant->id,
                    'eid' => $this->enseignant->eid,
                    'fonction_enseignant' => $this->enseignant->fonction_enseignant,
                ] : null,
                Role::Agent => null,
            },
        ];
    }
}
