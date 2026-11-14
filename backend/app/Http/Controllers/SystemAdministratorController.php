<?php

namespace App\Http\Controllers;

use App\Models\Utilisateur;
use App\Services\SystemAdministratorAccess;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class SystemAdministratorController extends Controller
{
    public function __construct(private readonly SystemAdministratorAccess $access) {}

    public function index(Request $request): JsonResponse
    {
        $this->authorizeAdministrator($request);
        $configuredLogins = config('academic.publication_admin_logins', []);
        $rows = DB::table('gnu.utilisateur as u')
            ->leftJoin('gnu.agent_administrateur_systeme as aa', 'aa.agent_id', '=', 'u.id')
            ->where('u.role', 'AGENT')
            ->where(function ($query) use ($configuredLogins): void {
                $query->whereNotNull('aa.agent_id');
                if ($configuredLogins !== []) {
                    $query->orWhereIn(DB::raw('lower(u.login)'), $configuredLogins);
                }
            })
            ->orderBy('u.nom')->orderBy('u.prenom')
            ->get([
                'u.id', 'u.login', 'u.actif', 'u.nom', 'u.prenom', 'u.courriel',
                'aa.agent_id as administrateur_base_id',
            ]);
        $departmentRows = DB::table('gnu.agent_departement as ad')
            ->join('gnu.departement as d', 'd.id', '=', 'ad.departement_id')
            ->whereIn('ad.agent_id', $rows->pluck('id')->all())
            ->orderBy('d.code_de')
            ->get(['ad.agent_id', 'd.id as departement_id', 'd.code_de', 'd.nom_depart'])
            ->groupBy('agent_id');
        $admins = $rows->map(function (object $row) use ($configuredLogins, $departmentRows): array {
            $configured = in_array(mb_strtolower(trim($row->login)), $configuredLogins, true);

            return [
                'id' => (int) $row->id,
                'login' => $row->login,
                'actif' => (bool) $row->actif,
                'nom' => $row->nom,
                'prenom' => $row->prenom,
                'courriel' => $row->courriel,
                'source' => $configured ? 'CONFIGURATION' : 'BASE_DE_DONNEES',
                'departements' => $departmentRows->get($row->id, collect())
                    ->map(static fn (object $department): array => [
                        'id' => (int) $department->departement_id,
                        'code' => $department->code_de,
                        'nom' => $department->nom_depart,
                    ])->values()->all(),
            ];
        })->values();

        return response()->json(['data' => $admins, 'administrateurs_actifs' => $this->access->activeAdministratorCount()]);
    }

    public function grant(Request $request, int $utilisateur): JsonResponse
    {
        $this->authorizeAdministrator($request);
        $data = $request->validate([
            'motif' => ['required', 'string', 'min:8', 'max:500'],
        ]);

        $created = DB::transaction(function () use ($request, $data, $utilisateur): bool {
            $this->access->lockAdministratorGrants();
            $this->authorizeAdministrator($request);
            $target = DB::table('gnu.utilisateur')->where('id', $utilisateur)->lockForUpdate()
                ->first(['id', 'login', 'role', 'actif']);
            abort_unless($target !== null && $target->role === 'AGENT', 404, 'Compte Agent introuvable.');
            abort_unless((bool) $target->actif, 422, 'Activez le compte Agent avant de lui accorder les droits administrateur.');

            if ($this->access->isConfiguredLogin((string) $target->login)
                || DB::table('gnu.agent_administrateur_systeme')->where('agent_id', $utilisateur)->exists()) {
                return false;
            }
            abort_unless(DB::table('gnu.agent_departement')->where('agent_id', $utilisateur)->exists(), 422, 'Le compte doit être rattaché à un département.');

            $this->setAuditContext($request, $data['motif']);

            return DB::table('gnu.agent_administrateur_systeme')->insertOrIgnore([
                'agent_id' => $utilisateur,
                'created_at' => now(),
            ]) > 0;
        });

        return response()->json([
            'message' => $created ? 'Droits administrateur système accordés.' : 'Ce compte est déjà administrateur système.',
            'data' => ['utilisateur_id' => $utilisateur, 'administrateur_systeme' => true],
        ], $created ? 201 : 200);
    }

    public function revoke(Request $request, int $utilisateur): JsonResponse
    {
        $this->authorizeAdministrator($request);
        $data = $request->validate([
            'motif' => ['required', 'string', 'min:8', 'max:500'],
        ]);

        DB::transaction(function () use ($request, $data, $utilisateur): void {
            $this->access->lockAdministratorGrants();
            $this->authorizeAdministrator($request);
            abort_if((int) $request->user()->id === $utilisateur, 422, 'Un autre administrateur doit révoquer vos droits.');
            $target = DB::table('gnu.utilisateur')->where('id', $utilisateur)->lockForUpdate()
                ->first(['id', 'login', 'role']);
            abort_unless($target !== null && $target->role === 'AGENT', 404, 'Compte Agent introuvable.');
            abort_if($this->access->isConfiguredLogin((string) $target->login), 409, 'Les administrateurs définis dans la configuration doivent être retirés de GNU_PUBLICATION_ADMIN_LOGINS.');

            $this->setAuditContext($request, $data['motif']);
            $deleted = DB::table('gnu.agent_administrateur_systeme')->where('agent_id', $utilisateur)->delete();
            abort_unless($deleted > 0, 404, 'Aucun droit administrateur attribué à ce compte.');
            abort_if($this->access->activeAdministratorCount() < 1, 409, 'Le dernier administrateur système actif ne peut pas être révoqué.');
        });

        return response()->json([
            'message' => 'Droits administrateur système révoqués.',
            'data' => ['utilisateur_id' => $utilisateur, 'administrateur_systeme' => false],
        ]);
    }

    private function authorizeAdministrator(Request $request): void
    {
        $user = $request->user();
        abort_unless($user instanceof Utilisateur && $this->access->isAdministrator($user), 403, 'Cette action est réservée à un administrateur système.');
    }

    private function setAuditContext(Request $request, string $reason): void
    {
        DB::select("SELECT set_config('gnu.acteur_id', ?, true), set_config('gnu.motif', ?, true)", [
            (string) $request->user()->id,
            trim($reason),
        ]);
    }
}
