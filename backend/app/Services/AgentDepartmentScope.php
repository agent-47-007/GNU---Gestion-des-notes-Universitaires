<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;

class AgentDepartmentScope
{
    /** @return array<int, int> */
    public function departmentIds(int $userId): array
    {
        return DB::table('gnu.agent_departement as ad')
            ->join('gnu.utilisateur as u', 'u.id', '=', 'ad.agent_id')
            ->where('ad.agent_id', $userId)
            ->where('u.role', 'AGENT')
            ->where('u.actif', true)
            ->orderBy('ad.departement_id')
            ->pluck('ad.departement_id')
            ->map(static fn (mixed $id): int => (int) $id)
            ->all();
    }

    /** @param array<int, int> $departmentIds */
    public function hasClass(array $departmentIds, int $classId): bool
    {
        return DB::table('gnu.classe as c')
            ->join('gnu.niveau as n', 'n.id', '=', 'c.niveau_id')
            ->join('gnu.filiere as f', 'f.id', '=', 'n.filiere_id')
            ->where('c.id', $classId)
            ->whereIn('f.departement_id', $departmentIds)
            ->exists();
    }

    /** @param array<int, int> $departmentIds */
    public function hasLevel(array $departmentIds, int $levelId): bool
    {
        return DB::table('gnu.niveau as n')
            ->join('gnu.filiere as f', 'f.id', '=', 'n.filiere_id')
            ->where('n.id', $levelId)
            ->whereIn('f.departement_id', $departmentIds)
            ->exists();
    }

    /** @param array<int, int> $departmentIds */
    public function hasUnit(array $departmentIds, int $unitId): bool
    {
        return DB::table('gnu.ue as u')
            ->join('gnu.niveau as n', 'n.id', '=', 'u.niveau_id')
            ->join('gnu.filiere as f', 'f.id', '=', 'n.filiere_id')
            ->where('u.id', $unitId)
            ->whereIn('f.departement_id', $departmentIds)
            ->exists();
    }

    /** @param array<int, int> $departmentIds */
    public function visibleUserIds(array $departmentIds): array
    {
        $studentIds = DB::table('gnu.etudiant as e')
            ->join('gnu.inscription_classe as ic', 'ic.etudiant_id', '=', 'e.id')
            ->join('gnu.classe as c', 'c.id', '=', 'ic.classe_id')
            ->join('gnu.niveau as n', 'n.id', '=', 'c.niveau_id')
            ->join('gnu.filiere as f', 'f.id', '=', 'n.filiere_id')
            ->whereIn('f.departement_id', $departmentIds)
            ->pluck('e.utilisateur_id');
        $teacherIds = DB::table('gnu.enseignant as e')
            ->join('gnu.affectation as a', 'a.enseignant_id', '=', 'e.id')
            ->join('gnu.classe as c', 'c.id', '=', 'a.classe_id')
            ->join('gnu.niveau as n', 'n.id', '=', 'c.niveau_id')
            ->join('gnu.filiere as f', 'f.id', '=', 'n.filiere_id')
            ->whereIn('f.departement_id', $departmentIds)
            ->pluck('e.utilisateur_id');
        $agentIds = DB::table('gnu.agent_departement')
            ->whereIn('departement_id', $departmentIds)
            ->pluck('agent_id');

        return $studentIds->concat($teacherIds)->concat($agentIds)->unique()->map(static fn (mixed $id): int => (int) $id)->values()->all();
    }
}
