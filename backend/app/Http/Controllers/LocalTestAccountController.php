<?php

namespace App\Http\Controllers;

use Illuminate\Database\QueryException;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;
use Illuminate\View\View;

class LocalTestAccountController extends Controller
{
    public function index(): View
    {
        $this->ensureEnabled();
        $connection = DB::connection('pgsql_setup');

        try {
            $departments = $connection->table('gnu.departement')->orderBy('nom_depart')->get(['id', 'nom_depart']);
            $classes = $connection->table('gnu.classe')->orderBy('code_classe')->get(['id', 'code_classe']);
        } catch (\Throwable $exception) {
            report($exception);
            abort(503, 'Impossible de lire les référentiels locaux. Démarrez PostgreSQL et appliquez les migrations avant d’ouvrir ce portail.');
        }

        return view('local-test-accounts', compact('departments', 'classes'));
    }

    public function store(Request $request): RedirectResponse
    {
        $this->ensureEnabled();
        $data = $request->validate([
            'role' => ['required', 'in:ETUDIANT,ENSEIGNANT,AGENT'],
            'login' => ['required', 'string', 'max:64', 'regex:/^[A-Za-z0-9._-]+$/'],
            'code_utilisateur' => ['required', 'string', 'max:64', 'regex:/^[A-Za-z0-9._-]+$/'],
            'nom' => ['required', 'string', 'max:128'],
            'prenom' => ['nullable', 'string', 'max:128'],
            'password' => ['required', 'string', 'min:12', 'confirmed'],
            'profil_id' => ['required', 'string', 'max:64'],
            'courriel' => ['nullable', 'email:rfc', 'max:254'],
            'classe_id' => ['nullable', 'required_if:role,ETUDIANT', 'integer', 'min:1'],
            'departement_id' => ['nullable', 'required_if:role,AGENT', 'integer', 'min:1'],
        ]);

        $connection = DB::connection('pgsql_setup');
        $login = trim($data['login']);
        $code = trim($data['code_utilisateur']);
        $profileId = trim($data['profil_id']);
        $data['login'] = $login;
        $data['code_utilisateur'] = $code;
        $data['profil_id'] = $profileId;
        $data['nom'] = trim($data['nom']);
        $data['prenom'] = isset($data['prenom']) ? trim($data['prenom']) : null;
        try {
            $connection->transaction(function () use ($connection, $data, $login, $code, $profileId): void {
                if ($data['role'] === 'ETUDIANT' && ! $connection->table('gnu.classe')->where('id', $data['classe_id'])->exists()) {
                    throw ValidationException::withMessages(['classe_id' => 'La classe sélectionnée n’existe plus. Rechargez la page et choisissez une classe disponible.']);
                }
                if ($data['role'] === 'AGENT' && ! $connection->table('gnu.departement')->where('id', $data['departement_id'])->exists()) {
                    throw ValidationException::withMessages(['departement_id' => 'Le département sélectionné n’existe pas. Rechargez la page et choisissez un département disponible.']);
                }
                if (($data['role'] === 'ETUDIANT' && $connection->table('gnu.etudiant')->where('matricule', $profileId)->exists())
                    || ($data['role'] === 'ENSEIGNANT' && $connection->table('gnu.enseignant')->where('eid', $profileId)->exists())) {
                    throw ValidationException::withMessages(['profil_id' => 'Cet identifiant de profil existe déjà. Choisissez-en un autre.']);
                }
                $duplicateAccount = $connection->table('gnu.utilisateur')->where('login', $login)
                    ->orWhere('code_utilisateur', $code)
                    ->when($data['courriel'] ?? null, fn ($query, string $email) => $query->orWhereRaw('lower(courriel) = ?', [strtolower(trim($email))]))
                    ->exists();
                if ($duplicateAccount) {
                    throw ValidationException::withMessages(['login' => 'Le login, le code utilisateur ou le courriel existe déjà. Choisissez des identifiants différents.']);
                }

                $connection->statement("SELECT set_config('gnu.origine', 'PORTAIL_TEST_LOCAL', true)");
                $connection->statement("SELECT set_config('gnu.motif', 'Création d’un compte local de recette', true)");
                $sequence = $connection->selectOne('SELECT pg_get_serial_sequence(?, ?) AS name', ['gnu.utilisateur', 'id'])->name;
                abort_unless($sequence !== null, 503, 'Séquence utilisateur introuvable.');
                $userId = (int) $connection->selectOne('SELECT nextval(?::regclass) AS id', [$sequence])->id;
                abort_unless($userId > 0, 503, 'La séquence du compteur utilisateur est introuvable.');
                $connection->statement("SELECT set_config('gnu.acteur_id', ?, true)", [(string) $userId]);
                $connection->insert('INSERT INTO gnu.utilisateur (id, code_utilisateur, login, mot_de_passe_hash, role, actif, nom, prenom, courriel, created_at, updated_at) OVERRIDING SYSTEM VALUE VALUES (?, ?, ?, ?, ?, true, ?, ?, ?, ?, ?)', [
                    $userId,
                    $code,
                    $login,
                    Hash::make($data['password']),
                    $data['role'],
                    $data['nom'],
                    $data['prenom'],
                    isset($data['courriel']) ? strtolower(trim($data['courriel'])) : null,
                    now(),
                    now(),
                ]);

                if ($data['role'] === 'ETUDIANT') {
                    $studentSequence = $connection->selectOne('SELECT pg_get_serial_sequence(?, ?) AS name', ['gnu.etudiant', 'id'])->name;
                    abort_unless($studentSequence !== null, 503, 'Séquence étudiant introuvable.');
                    $studentId = (int) $connection->selectOne('SELECT nextval(?::regclass) AS id', [$studentSequence])->id;
                    $connection->insert('INSERT INTO gnu.etudiant (id, matricule, utilisateur_id, created_at, updated_at) OVERRIDING SYSTEM VALUE VALUES (?, ?, ?, ?, ?)', [
                        $studentId,
                        $profileId,
                        $userId,
                        now(),
                        now(),
                    ]);
                    $connection->table('gnu.inscription_classe')->insert([
                        'etudiant_id' => $studentId,
                        'classe_id' => $data['classe_id'],
                        'statut_redoublant' => false,
                        // This local setup portal represents the registrar's test-account
                        // workflow, so the student can immediately exercise enrollment.
                        'statut_inscription' => 'VALIDEE',
                        'created_at' => now(),
                        'updated_at' => now(),
                    ]);
                } elseif ($data['role'] === 'ENSEIGNANT') {
                    $teacherSequence = $connection->selectOne('SELECT pg_get_serial_sequence(?, ?) AS name', ['gnu.enseignant', 'id'])->name;
                    abort_unless($teacherSequence !== null, 503, 'Séquence enseignant introuvable.');
                    $teacherId = (int) $connection->selectOne('SELECT nextval(?::regclass) AS id', [$teacherSequence])->id;
                    $connection->insert('INSERT INTO gnu.enseignant (id, eid, utilisateur_id, fonction_enseignant, created_at, updated_at) OVERRIDING SYSTEM VALUE VALUES (?, ?, ?, ?, ?, ?)', [
                        $teacherId,
                        $profileId,
                        $userId,
                        'Enseignant de test',
                        now(),
                        now(),
                    ]);
                } else {
                    $connection->table('gnu.agent_departement')->insert([
                        'agent_id' => $userId,
                        'departement_id' => $data['departement_id'],
                        'created_at' => now(),
                    ]);
                }
            });
        } catch (QueryException $exception) {
            report($exception);
            $sqlState = $exception->errorInfo[0] ?? (string) $exception->getCode();
            $message = match ($sqlState) {
                '23505' => 'Un login, code utilisateur, courriel ou identifiant de profil existe déjà. Vérifiez les champs et choisissez des valeurs uniques.',
                '23503' => 'Une référence sélectionnée n’est plus disponible. Rechargez la page et choisissez de nouveau la classe ou le département.',
                '23514' => 'Les informations ne respectent pas une règle de la base. Vérifiez le rôle et les champs requis.',
                '42501' => 'Le compte gnu_setup n’a pas encore tous les droits PostgreSQL nécessaires à cette création.',
                default => 'La base a refusé la création du compte. Vérifiez les informations saisies ou consultez backend/storage/logs/laravel.log.',
            };

            throw ValidationException::withMessages(['creation' => $message]);
        }

        return redirect()->route('local-test-accounts.index')->with('created_login', $login)->with('status', 'Compte créé. Note le login et le mot de passe choisi avant de quitter cette page.');
    }

    private function ensureEnabled(): void
    {
        abort_unless(app()->environment('local') && config('academic.local_test_account_portal'), 404);
        $host = strtolower((string) config('database.connections.pgsql_setup.host'));
        $allowedHosts = ['localhost', '127.0.0.1', '::1'];
        abort_unless(in_array($host, $allowedHosts, true), 404);
        abort_unless(config('database.connections.pgsql_setup.database') === config('database.connections.pgsql.database'), 404);
        abort_unless(config('database.connections.pgsql_setup.username') !== config('database.connections.pgsql.username'), 404);
    }
}
