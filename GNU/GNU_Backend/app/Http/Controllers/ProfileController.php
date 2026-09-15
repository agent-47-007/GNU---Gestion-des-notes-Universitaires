<?php

namespace App\Http\Controllers;

use App\Http\Resources\UtilisateurResource;
use Illuminate\Http\Request;

class ProfileController extends Controller
{
    public function show(Request $request): UtilisateurResource
    {
        return new UtilisateurResource($request->user());
    }
}
