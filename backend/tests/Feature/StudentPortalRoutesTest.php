<?php

namespace Tests\Feature;

use Tests\TestCase;

class StudentPortalRoutesTest extends TestCase
{
    public function test_student_portal_routes_require_authentication(): void
    {
        $routes = [
            ['getJson', '/api/v1/profil/etudiant'],
            ['putJson', '/api/v1/etudiant/profil'],
            ['getJson', '/api/v1/etudiant/inscriptions?semestre=1'],
            ['putJson', '/api/v1/etudiant/inscriptions'],
            ['postJson', '/api/v1/etudiant/inscriptions/soumettre'],
            ['getJson', '/api/v1/etudiant/resultats'],
            ['getJson', '/api/v1/etudiant/requetes'],
            ['postJson', '/api/v1/etudiant/requetes'],
            ['getJson', '/api/v1/etudiant/requetes/1/justificatif'],
            ['getJson', '/api/v1/etudiant/rattrapages'],
            ['getJson', '/api/v1/etudiant/notifications'],
            ['patchJson', '/api/v1/etudiant/notifications/1/lue'],
            ['getJson', '/api/v1/enseignant/affectations'],
            ['getJson', '/api/v1/enseignant/affectations/1/plan-evaluation'],
            ['patchJson', '/api/v1/agent/inscriptions/1'],
        ];

        foreach ($routes as [$method, $uri]) {
            $this->{$method}($uri)->assertUnauthorized();
        }
    }
}
