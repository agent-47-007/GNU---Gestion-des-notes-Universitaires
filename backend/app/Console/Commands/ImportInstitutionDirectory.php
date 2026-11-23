<?php

namespace App\Console\Commands;

use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;
use Throwable;

#[Signature('gnu:import-annuaire {--database=pgsql_setup : Connexion de configuration de la base cible}')]
#[Description('Importe le référentiel public MINESUP sans créer de comptes ni modifier les dossiers académiques')]
class ImportInstitutionDirectory extends Command
{
    public function handle(): int
    {
        $data = json_decode(file_get_contents(database_path('data/institutions_cameroun.json')), true, 512, JSON_THROW_ON_ERROR);
        $validation = Validator::make($data, [
            'consulte_le' => ['required', 'date'], 'limite' => ['required', 'string'],
            'sources' => ['required', 'array'], 'institutions' => ['required', 'array', 'min:11'],
            'institutions.*.source_key' => ['required', 'string', 'max:80', 'distinct'],
            'institutions.*.nom' => ['required', 'string', 'max:500'],
            'institutions.*.categorie' => ['required', 'in:UNIVERSITE_PUBLIQUE,IPES,INSTITUTION_PRIVEE,INTERNATIONAL'],
            'institutions.*.region' => ['nullable', 'string', 'max:80'],
            'institutions.*.ville' => ['nullable', 'string', 'max:120'],
            'institutions.*.source_url' => ['required', 'url:https'],
            'institutions.*.source_liste_url' => ['required', 'url:https'],
            'institutions.*.source_date' => ['nullable', 'date'],
            'institutions.*.site_web' => ['nullable', 'url:https'],
            'institutions.*.verification' => ['required', 'string', 'max:60'],
            'institutions.*.code_universite' => ['nullable', 'string', 'max:20'],
        ]);
        if ($validation->fails()) {
            $this->components->error(array_key_first($validation->errors()->messages()).' : '.$validation->errors()->first());

            return self::FAILURE;
        }
        $connection = DB::connection((string) $this->option('database'));
        try {
            $connection->transaction(function () use ($connection, $data): void {
                $connection->select("SELECT set_config('gnu.motif', 'Import du répertoire public MINESUP', true)");
                foreach ($data['institutions'] as $entry) {
                    $code = $entry['code_universite'];
                    $universityId = $code === null ? null : $connection->table('gnu.universite')->where('code_univ', $code)->value('id');
                    if ($code !== null && $universityId === null) {
                        $universityId = $connection->table('gnu.universite')->insertGetId(['code_univ' => $code, 'nom_univ' => $entry['nom']]);
                    }
                    unset($entry['code_universite']);
                    $key = $entry['source_key'];
                    unset($entry['source_key']);
                    $entry['recherche'] = Str::lower(Str::ascii($entry['nom'].' '.($entry['ville'] ?? '')));
                    $entry['universite_id'] = $universityId;
                    $entry['consulte_le'] = $data['consulte_le'];
                    $entry['updated_at'] = now();
                    $existing = $connection->table('gnu.annuaire_institution')->where('source_key', $key);
                    if ($existing->exists()) {
                        $existing->update($entry);
                    } else {
                        $connection->table('gnu.annuaire_institution')->insert($entry + ['source_key' => $key, 'created_at' => now()]);
                    }
                }
                unset($data['institutions']);
                $connection->table('gnu.annuaire_metadata')->updateOrInsert(['cle' => 'sources'], ['contenu' => json_encode($data, JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE), 'updated_at' => now()]);
            });
        } catch (Throwable $exception) {
            $this->components->error('Import annulé : '.$exception->getMessage());

            return self::FAILURE;
        }
        $this->components->info(count($data['institutions']).' entrées du répertoire importées dans '.$connection->getDatabaseName().'. Aucun compte créé.');

        return self::SUCCESS;
    }
}
