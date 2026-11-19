<?php

namespace App\Services;

use Closure;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\Process\Process;

class PublishedTranscript
{
    /** Called under a transaction lock for this bulletin, after checking its owner. */
    public function archive(int $bulletin, int $actor, Closure $load): array
    {
        $disk = Storage::disk('local');
        $prefix = 'bulletins/generes/'.$bulletin.'/';
        $archive = DB::table('gnu.document_bulletin')->where('bulletin_id', $bulletin);
        $existing = $archive->first();
        if ($existing && str_starts_with($existing->chemin_fichier, $prefix)) {
            $bytes = $disk->get($existing->chemin_fichier);
            if (is_string($bytes) && hash_equals(trim($existing->empreinte_sha256), hash('sha256', $bytes))) {
                return ['bytes' => $bytes, 'reference' => $existing->reference_officielle];
            }
        }

        $row = $load();
        $reference = $row['reference_officielle'];
        $process = new Process([base_path('vendor/bin/gnu-transcript'), base_path('../frontend/assets')]);
        $process->setInput(json_encode($row, JSON_THROW_ON_ERROR));
        $process->mustRun();
        $bytes = $process->getOutput();
        abort_unless(str_starts_with($bytes, '%PDF-'), 500, 'Génération du relevé impossible.');
        $hash = hash('sha256', $bytes);
        $path = $prefix.$hash.'.pdf';
        abort_unless($disk->put($path, $bytes), 500, 'Archivage du relevé impossible.');
        DB::select("SELECT set_config('gnu.acteur_id', ?, true), set_config('gnu.motif', ?, true)", [(string) $actor, 'Génération du bulletin '.$reference]);
        $metadata = [
            'reference_officielle' => $reference, 'chemin_fichier' => $path,
            'empreinte_sha256' => $hash, 'genere_par' => $actor,
            'date_emission' => now(), 'updated_at' => now(),
        ];
        if ($existing) {
            $archive->update($metadata);
        } else {
            DB::table('gnu.document_bulletin')->insert($metadata + ['bulletin_id' => $bulletin, 'created_at' => now()]);
        }

        return ['bytes' => $bytes, 'reference' => $reference];
    }
}
