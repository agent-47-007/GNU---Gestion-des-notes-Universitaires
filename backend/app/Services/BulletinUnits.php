<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;

class BulletinUnits
{
    /** Resolve the academic year of carried credits from their source bulletin. */
    public static function withSourceYears(array $rows): array
    {
        $ids = collect($rows)->flatMap(fn (array $row) => $row['contenu']['ues'] ?? [])
            ->pluck('source_bulletin_id')->filter()->unique()->values();
        if ($ids->isEmpty()) {
            return $rows;
        }
        $years = DB::table('gnu.bulletin as b')
            ->join('gnu.publication as p', 'p.id', '=', 'b.publication_id')
            ->join('gnu.classe as c', 'c.id', '=', 'p.classe_id')
            ->join('gnu.annee_academique as an', 'an.id', '=', 'c.annee_id')
            ->whereIn('b.id', $ids)->pluck('an.libelle', 'b.id');
        foreach ($rows as $i => $row) {
            foreach ($row['contenu']['ues'] ?? [] as $j => $unit) {
                if (isset($unit['source_bulletin_id'])) {
                    $rows[$i]['contenu']['ues'][$j]['annee_obtention'] = $years->get($unit['source_bulletin_id']);
                }
            }
        }

        return $rows;
    }
}
