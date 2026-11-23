<?php

namespace App\Console\Commands;

use App\Services\AcademicDirectoryImporter;
use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Throwable;

#[Signature('gnu:import-formations {--database=pgsql_setup}')]
#[Description('Importe les formations sourcées sans créer de comptes, classes ni notes')]
class ImportAcademicDirectory extends Command
{
    /**
     * Execute the console command.
     */
    public function handle(AcademicDirectoryImporter $importer): int
    {
        $data = json_decode(file_get_contents(database_path('data/formations_cameroun.json')), true, 512, JSON_THROW_ON_ERROR);
        $validation = Validator::make($data, [
            'consulte_le' => ['required', 'date'], 'annee_cible' => ['required', 'in:2026-2027'],
            'universites' => ['required', 'array', 'min:1'],
            'universites.*.code' => ['required', 'string', 'max:20', 'distinct'],
            'universites.*.etablissements' => ['required', 'array'],
            'universites.*.etablissements.*.code' => ['required', 'string', 'max:20'],
            'universites.*.etablissements.*.nom' => ['required', 'string', 'max:500'],
            'universites.*.etablissements.*.source_url' => ['required', 'url:https'],
            'universites.*.etablissements.*.departements' => ['present', 'array'],
            'universites.*.etablissements.*.departements.*.code' => ['required', 'string', 'max:20'],
            'universites.*.etablissements.*.departements.*.nom' => ['required', 'string', 'max:500'],
            'universites.*.etablissements.*.departements.*.source_url' => ['required', 'url:https'],
            'universites.*.etablissements.*.departements.*.formations' => ['present', 'array'],
            'universites.*.etablissements.*.departements.*.formations.*.code' => ['required', 'string', 'max:20'],
            'universites.*.etablissements.*.departements.*.formations.*.nom' => ['required', 'string', 'max:500'],
            'universites.*.etablissements.*.departements.*.formations.*.source_url' => ['required', 'url:https'],
            'universites.*.etablissements.*.departements.*.formations.*.cycle' => ['nullable', 'in:LICENCE,MASTER,DOCTORAT'],
            'universites.*.etablissements.*.departements.*.formations.*.niveaux' => ['present', 'array'],
            'universites.*.etablissements.*.departements.*.formations.*.niveaux.*' => ['string', 'regex:/^(L[1-4]|M[12]|D[1-3])$/'],
        ]);
        if ($validation->fails()) {
            $this->components->error(array_key_first($validation->errors()->messages()).' : '.$validation->errors()->first());

            return self::FAILURE;
        }
        try {
            $connection = DB::connection((string) $this->option('database'));
            $counts = $connection->transaction(fn () => $importer->import($connection, $data));
        } catch (Throwable $exception) {
            $this->components->error('Import annulé : '.$exception->getMessage());

            return self::FAILURE;
        }
        $this->components->info(json_encode($counts, JSON_UNESCAPED_UNICODE).' — Aucun compte, classe ou note créé.');

        return self::SUCCESS;
    }
}
