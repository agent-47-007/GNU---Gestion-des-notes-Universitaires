<?php

namespace App\Enums;

enum Role: string
{
    case Etudiant = 'ETUDIANT';
    case Enseignant = 'ENSEIGNANT';
    case Agent = 'AGENT';
}
