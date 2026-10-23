<?php

namespace App\Http\Requests;

use App\Rules\PasswordByteLength;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rules\Password;

class ChangePasswordRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    public function rules(): array
    {
        return [
            'current_password' => ['required', 'string', new PasswordByteLength],
            'password' => ['required', 'string', 'confirmed', 'different:current_password', Password::min(12)->letters()->numbers(), new PasswordByteLength],
        ];
    }
}
