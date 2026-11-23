<?php

namespace App\Services;

use Illuminate\Database\Connection;
use Illuminate\Support\Str;
use RuntimeException;

class AcademicDirectoryImporter
{
    public function import(Connection $connection, array $data): array
    {
        $counts = ['universites' => 0, 'etablissements' => 0, 'departements' => 0, 'formations' => 0, 'niveaux' => 0];
        $connection->select("SELECT set_config('gnu.motif', 'Complément sourcé du référentiel académique public', true)");
        foreach ($data['universites'] as $university) {
            $universityId = $connection->table('gnu.universite')->where('code_univ', $university['code'])->value('id');
            if ($universityId === null) {
                throw new RuntimeException('Importer l’annuaire avant les formations : '.$university['code']);
            }
            $counts['universites']++;
            foreach ($university['etablissements'] as $school) {
                $schoolId = $this->findOrCreate($connection, 'faculte', 'universite_id', $universityId, 'code_fac', 'nom_fac', $school['code'], $school['nom']);
                $this->source($connection, 'faculte', $schoolId, $school, $data['consulte_le'], ['formations' => $school['formations'] ?? []]);
                $counts['etablissements']++;
                foreach ($school['departements'] as $department) {
                    $departmentId = $this->findOrCreate($connection, 'departement', 'faculte_id', $schoolId, 'code_de', 'nom_depart', $department['code'], $department['nom']);
                    $this->source($connection, 'departement', $departmentId, $department, $data['consulte_le']);
                    $counts['departements']++;
                    foreach ($department['formations'] as $program) {
                        $programId = $this->findOrCreate($connection, 'filiere', 'departement_id', $departmentId, 'code_f', 'nom_f', $program['code'], $program['nom']);
                        $this->source($connection, 'filiere', $programId, $program, $data['consulte_le'], [
                            'cycle' => $program['cycle'], 'duree' => $program['duree'],
                            'niveaux' => $program['niveaux'], 'methode_niveaux' => $program['methode_niveaux'],
                        ]);
                        $counts['formations']++;
                        foreach ($program['niveaux'] as $level) {
                            $expectedCycle = match ($level[0]) {
                                'L' => 'LICENCE', 'M' => 'MASTER', 'D' => 'DOCTORAT'
                            };
                            if ($program['cycle'] !== $expectedCycle) {
                                throw new RuntimeException('Cycle incohérent pour '.$program['nom'].' : '.$level);
                            }
                            if (! $connection->table('gnu.niveau')->where('filiere_id', $programId)->where('code_niv', $level)->exists()) {
                                $connection->table('gnu.niveau')->insert(['filiere_id' => $programId, 'code_niv' => $level,
                                    'cycle_niv' => $expectedCycle, 'libelle_niv' => ucfirst(strtolower($expectedCycle)).' '.$level[1]]);
                            }
                            $counts['niveaux']++;
                        }
                    }
                }
            }
        }
        $connection->table('gnu.annuaire_metadata')->updateOrInsert(['cle' => 'formations'], [
            'contenu' => json_encode(['consulte_le' => $data['consulte_le'], 'annee_cible' => $data['annee_cible'],
                'limite' => $data['limite'], 'couverture' => $counts], JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE), 'updated_at' => now(),
        ]);

        return $counts;
    }

    private function findOrCreate(Connection $connection, string $table, string $parentColumn, int $parentId, string $codeColumn, string $nameColumn, string $code, string $name): int
    {
        $siblings = $connection->table('gnu.'.$table)->where($parentColumn, $parentId)->get(['id', $codeColumn, $nameColumn]);
        foreach ($siblings as $sibling) {
            if ($sibling->{$codeColumn} === $code || $this->normalize($sibling->{$nameColumn}) === $this->normalize($name)) {
                return (int) $sibling->id;
            }
        }

        return $connection->table('gnu.'.$table)->insertGetId([$parentColumn => $parentId, $codeColumn => $code, $nameColumn => $name]);
    }

    private function normalize(string $name): string
    {
        $name = Str::lower(Str::ascii($name));
        $name = preg_replace('/^(?:departement\s+(?:de\s+|des\s+|d[’\x27])?|department\s+of\s+)/u', '', $name);

        return preg_replace('/[^a-z0-9]+/', '', $name);
    }

    private function source(Connection $connection, string $type, int $id, array $entry, string $consultedAt, array $details = []): void
    {
        $connection->table('gnu.annuaire_structure_source')->updateOrInsert([
            'source_key' => hash('sha256', $type.':'.$id.':'.$entry['source_url']),
        ], ['objet_type' => $type, 'objet_id' => $id, 'source_url' => $entry['source_url'],
            'consulte_le' => $consultedAt, 'source_date' => $entry['source_date'] ?? null,
            'annee_source' => $entry['annee_source'] ?? null,
            'details' => json_encode($details, JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE),
        ]);
    }
}
