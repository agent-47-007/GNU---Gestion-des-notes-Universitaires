<?php

namespace App\Services;

class BulletinReference
{
    public function make(string $year, string $class, string $matricule, string $period, int $version): string
    {
        $year = $this->normalize($year) ?: 'ANNEE';
        $class = $this->normalize($class) ?: 'CLASSE';
        $matricule = $this->normalize($matricule) ?: 'ETUDIANT';
        $period = $this->normalize($period) ?: 'PERIODE';

        return implode('-', [
            'UY1-RELEVE',
            $year,
            $class,
            $matricule,
            $period,
            'V'.$version,
        ]);
    }

    private function normalize(string $value): string
    {
        return trim(preg_replace('/[^A-Za-z0-9-]+/', '-', trim($value)) ?: '', '-');
    }
}
