<?php

namespace App\Http\Requests;

use App\Rules\PasswordByteLength;
use Illuminate\Foundation\Http\FormRequest;

class LoginRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'login' => ['required', 'string', 'max:100'],
            'password' => ['required', 'string', new PasswordByteLength],
            'device_name' => ['required', 'string', 'max:100'],
        ];
    }
}
