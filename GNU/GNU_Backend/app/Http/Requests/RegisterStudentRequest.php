<?php

namespace App\Http\Requests;

use App\Rules\PasswordByteLength;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class RegisterStudentRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'nom' => ['required', 'string', 'max:100'],
            'prenom' => ['required', 'string', 'max:100'],
            'matricule' => [
                'required',
                'string',
                'max:100',
                'regex:/^[A-Za-z0-9-]+$/',
                Rule::unique('gnu.etudiant', 'matricule'),
                Rule::unique('gnu.utilisateur', 'login'),
            ],
            'password' => ['required', 'string', 'min:5', 'confirmed', new PasswordByteLength],
        ];
    }

    protected function prepareForValidation(): void
    {
        $this->merge([
            'nom' => trim((string) $this->input('nom')),
            'prenom' => trim((string) $this->input('prenom')),
            'matricule' => strtoupper(trim((string) $this->input('matricule'))),
        ]);
    }
}