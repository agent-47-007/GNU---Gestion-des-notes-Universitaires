<?php

namespace Tests\Feature;

use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class PublicDirectoryTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        $socket = getenv('GNU_TRANSCRIPT_TEST_SOCKET');
        if (! $socket) {
            $this->markTestSkipped('Requires the isolated PostgreSQL test server.');
        }
        config(['database.connections.pgsql.host' => $socket, 'database.connections.pgsql.port' => 55436,
            'database.connections.pgsql.database' => 'postgres', 'database.connections.pgsql.username' => 'gnu_test',
            'database.connections.pgsql.password' => '']);
        DB::purge('pgsql');
        DB::beginTransaction();
        DB::unprepared("CREATE SCHEMA gnu;
            DO \$\$ BEGIN IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname='gnu_app') THEN CREATE ROLE gnu_app NOLOGIN; END IF; END \$\$;
            CREATE TABLE gnu.universite(id bigserial PRIMARY KEY, code_univ text UNIQUE, nom_univ text);
            CREATE TABLE gnu.faculte(id bigserial PRIMARY KEY, universite_id bigint, code_fac text, nom_fac text);
            CREATE TABLE gnu.departement(id bigserial PRIMARY KEY, faculte_id bigint, code_de text, nom_depart text);
            CREATE TABLE gnu.filiere(id bigserial PRIMARY KEY, departement_id bigint, code_f text, nom_f text);
            CREATE TABLE gnu.niveau(id bigserial PRIMARY KEY, filiere_id bigint, code_niv text, libelle_niv text, cycle_niv text);
            CREATE TABLE gnu.utilisateur(id int, login text, mot_de_passe_hash text);
            INSERT INTO gnu.utilisateur VALUES(1,'private-admin','DO-NOT-PUBLISH');");
        $migration = require database_path('migrations/2026_11_22_225652_create_public_institution_directory.php');
        $migration->up();
        $sourcesMigration = require database_path('migrations/2026_11_23_060253_create_public_training_sources.php');
        $sourcesMigration->up();
    }

    protected function tearDown(): void
    {
        if (DB::connection()->transactionLevel() > 0) {
            DB::rollBack();
        }
        parent::tearDown();
    }

    private function importDirectory(): void
    {
        $exitCode = Artisan::call('gnu:import-annuaire', ['--database' => 'pgsql']);
        $this->assertSame(0, $exitCode, Artisan::output());
    }

    public function test_import_is_repeatable_and_creates_no_accounts(): void
    {
        $expected = count(json_decode(file_get_contents(database_path('data/institutions_cameroun.json')), true)['institutions']);
        $this->importDirectory();
        $this->importDirectory();
        $this->assertSame($expected, DB::table('gnu.annuaire_institution')->count());
        $this->assertSame(11, DB::table('gnu.annuaire_institution')->where('categorie', 'UNIVERSITE_PUBLIQUE')->count());
        $this->assertSame(1, DB::table('gnu.utilisateur')->count());
        $this->assertNotNull(DB::table('gnu.universite')->where('code_univ', 'UY2')->first());
    }

    public function test_anonymous_directory_filters_pages_and_never_returns_accounts(): void
    {
        $this->importDirectory();
        $response = $this->getJson('/api/v1/public/institutions?categorie=UNIVERSITE_PUBLIQUE&per_page=3');
        $response->assertOk()->assertJsonCount(3, 'data')->assertJsonPath('pagination.total', 11);
        $this->assertStringNotContainsString('DO-NOT-PUBLISH', $response->getContent());
        $this->assertStringNotContainsString('mot_de_passe_hash', $response->getContent());
        $this->getJson('/api/v1/public/institutions?q=yaounde&categorie=UNIVERSITE_PUBLIQUE')
            ->assertOk()->assertJsonPath('pagination.total', 2);
        $this->getJson('/api/v1/public/institutions?q=%25')->assertOk()->assertJsonPath('pagination.total', 0);
        $this->getJson('/api/v1/public/institutions?per_page=999')->assertUnprocessable();
        $this->getJson('/api/v1/public/institutions?categorie=INVALID')->assertUnprocessable();
        $this->postJson('/api/v1/public/institutions', [])->assertStatus(405);
        $this->getJson('/api/v1/agent/comptes')->assertUnauthorized();
    }

    public function test_training_import_is_repeatable_scoped_and_does_not_invent_classes(): void
    {
        $this->importDirectory();
        $uy1University = DB::table('gnu.universite')->where('code_univ', 'UY1')->value('id');
        $existingFaculty = DB::table('gnu.faculte')->insertGetId(['universite_id' => $uy1University, 'code_fac' => 'FS', 'nom_fac' => 'Faculté des Sciences']);
        $existingDepartment = DB::table('gnu.departement')->insertGetId(['faculte_id' => $existingFaculty, 'code_de' => 'INFO', 'nom_depart' => 'Département d’Informatique']);
        $existingProgram = DB::table('gnu.filiere')->insertGetId(['departement_id' => $existingDepartment, 'code_f' => 'ICT4D', 'nom_f' => 'ICT FOR DEVELOPPEMENT']);
        $exit = Artisan::call('gnu:import-formations', ['--database' => 'pgsql']);
        $this->assertSame(0, $exit, Artisan::output());
        $this->assertSame($existingProgram, DB::table('gnu.filiere')->where('departement_id', $existingDepartment)->where('code_f', 'ICT4D')->value('id'));
        $this->assertSame('ICT FOR DEVELOPPEMENT', DB::table('gnu.filiere')->where('id', $existingProgram)->value('nom_f'));
        $counts = [];
        foreach (['faculte', 'departement', 'filiere', 'niveau', 'annuaire_structure_source'] as $table) {
            $counts[$table] = DB::table('gnu.'.$table)->count();
        }
        $this->assertSame(0, Artisan::call('gnu:import-formations', ['--database' => 'pgsql']), Artisan::output());
        foreach ($counts as $table => $count) {
            $this->assertSame($count, DB::table('gnu.'.$table)->count(), $table);
        }
        $this->assertGreaterThan(200, $counts['filiere']);
        $this->assertGreaterThan(300, $counts['niveau']);
        $this->assertSame(1, DB::table('gnu.utilisateur')->count());
        $id = DB::table('gnu.annuaire_institution')->where('source_key', 'UN')->value('id');
        $response = $this->getJson('/api/v1/public/institutions/'.$id)->assertOk();
        $this->assertStringContainsString('Master en Informatique', $response->getContent());
        $this->assertStringNotContainsString('COLTECH', $response->getContent());
        $this->assertStringContainsString('source_url', $response->getContent());
        $shortLicence = DB::table('gnu.filiere as f')->join('gnu.departement as d', 'd.id', '=', 'f.departement_id')
            ->join('gnu.faculte as s', 's.id', '=', 'd.faculte_id')->join('gnu.universite as u', 'u.id', '=', 's.universite_id')
            ->where('u.code_univ', 'UN')->where('f.nom_f', 'Licence professionnelle en Agroécologie')->value('f.id');
        $this->assertNotNull($shortLicence);
        $this->assertSame(0, DB::table('gnu.niveau')->where('filiere_id', $shortLicence)->count(), 'Une licence professionnelle d’un an ne devient pas L1/L2/L3.');
        $masterTwo = DB::table('gnu.filiere')->where('nom_f', 'Master II en Gouvernance Asilaire et Humanitaire')->value('id');
        $this->assertNotNull($masterTwo);
        $this->assertSame(['M2'], DB::table('gnu.niveau')->where('filiere_id', $masterTwo)->pluck('code_niv')->all());
        $uy1Id = DB::table('gnu.annuaire_institution')->where('source_key', 'UY1')->value('id');
        $uy1 = $this->getJson('/api/v1/public/institutions/'.$uy1Id)->assertOk()->json('data.etablissements');
        $sigl = collect($uy1)->flatMap(fn ($school) => $school['departements'])
            ->flatMap(fn ($department) => $department['filieres'])
            ->first(fn ($program) => str_contains($program['nom_f'], '(SIGL)'));
        $this->assertNotNull($sigl);
        $this->assertSame('2026-2027', $sigl['sources'][0]['annee_source']);
        $this->assertSame('2026-07-31', $sigl['sources'][0]['source_date']);
        $ucacId = DB::table('gnu.annuaire_institution')->where('source_key', 'UCAC')->value('id');
        $ucac = $this->getJson('/api/v1/public/institutions/'.$ucacId)->assertOk()->json('data.etablissements');
        $this->assertSame([], $ucac[0]['departements']);
        $this->assertNotEmpty($ucac[0]['sources'][0]['details']['formations']);
    }

    public function test_public_detail_only_contains_the_selected_university_structure(): void
    {
        $this->importDirectory();
        $uy1 = DB::table('gnu.universite')->where('code_univ', 'UY1')->value('id');
        $uy2 = DB::table('gnu.universite')->where('code_univ', 'UY2')->value('id');
        DB::table('gnu.faculte')->insert([
            ['id' => 1, 'universite_id' => $uy1, 'code_fac' => 'FS', 'nom_fac' => 'Sciences UY1'],
            ['id' => 2, 'universite_id' => $uy2, 'code_fac' => 'OTHER', 'nom_fac' => 'Other University Faculty'],
        ]);
        $id = DB::table('gnu.annuaire_institution')->where('source_key', 'UY1')->value('id');
        $this->getJson('/api/v1/public/institutions/'.$id)->assertOk()
            ->assertJsonCount(1, 'data.etablissements')->assertJsonPath('data.etablissements.0.nom_fac', 'Sciences UY1');
        $this->getJson('/api/v1/public/institutions/999999999')->assertNotFound();
    }
}
