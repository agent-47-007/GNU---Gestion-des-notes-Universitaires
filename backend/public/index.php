<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(204); exit; }

function jsonResponse(mixed $data, int $status = 200): never {
    http_response_code($status);
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

function db(): PDO {
    static $pdo;
    if ($pdo instanceof PDO) return $pdo;
    $dsn = sprintf('pgsql:host=%s;port=%s;dbname=%s', getenv('DB_HOST') ?: '127.0.0.1', getenv('DB_PORT') ?: '5435', getenv('DB_NAME') ?: 'gnu_notes');
    $pdo = new PDO($dsn, getenv('DB_USER') ?: 'postgres', getenv('DB_PASSWORD') ?: '', [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
    $pdo->exec("SET search_path TO gnu, public");
    return $pdo;
}

function body(): array {
    $raw = file_get_contents('php://input') ?: '{}';
    $value = json_decode($raw, true);
    return is_array($value) ? $value : [];
}

function route(): array {
    $path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';
    return [array_values(array_filter(explode('/', trim($path, '/')))), $_SERVER['REQUEST_METHOD']];
}

try {
    [$parts, $method] = route();
    $resource = $parts[0] ?? '';

    if ($resource === 'api' && ($parts[1] ?? '') === 'health') {
        db()->query('SELECT 1');
        jsonResponse(['status' => 'ok', 'service' => 'GNU API', 'database' => 'PostgreSQL']);
    }

    if ($resource !== 'api') jsonResponse(['name' => 'GNU Gestion des notes', 'docs' => '/api/health']);

    if (($parts[1] ?? '') === 'dashboard' && $method === 'GET') {
        $pdo = db();
        $queries = [
            'students' => 'SELECT count(*) FROM etudiant',
            'classes' => 'SELECT count(*) FROM classe',
            'evaluations' => 'SELECT count(*) FROM evaluation',
            'validated_notes' => "SELECT count(*) FROM note WHERE statut_note='VALIDEE'",
        ];
        $result = [];
        foreach ($queries as $key => $sql) $result[$key] = (int) $pdo->query($sql)->fetchColumn();
        jsonResponse($result);
    }

    if (($parts[1] ?? '') === 'classes' && $method === 'GET') {
        $rows = db()->query('SELECT c.id, c.code_classe, n.libelle_niv AS niveau, aa.libelle AS annee FROM classe c JOIN niveau n ON n.id=c.niveau_id JOIN annee_academique aa ON aa.id=c.annee_id ORDER BY c.code_classe')->fetchAll();
        jsonResponse($rows);
    }

    if (($parts[1] ?? '') === 'students' && $method === 'GET' && !isset($parts[2])) {
        $sql = "SELECT e.id, e.matricule, u.nom, u.prenom, c.code_classe FROM etudiant e JOIN utilisateur u ON u.id=e.utilisateur_id JOIN inscription_classe ic ON ic.etudiant_id=e.id JOIN classe c ON c.id=ic.classe_id WHERE ic.statut_inscription='VALIDEE' AND (:class_id IS NULL OR c.id=:class_id) ORDER BY e.matricule";
        $stmt = db()->prepare($sql); $classId = $_GET['class_id'] ?? null; $stmt->execute(['class_id' => $classId]);
        jsonResponse($stmt->fetchAll());
    }

    if (($parts[1] ?? '') === 'students' && isset($parts[2]) && ($parts[3] ?? '') === 'bulletin' && $method === 'GET') {
        $period = $_GET['period'] ?? 'S1';
        $stmt = db()->prepare("SELECT e.matricule, u.nom, u.prenom, ic.id AS inscription_classe_id, gnu.calculer_bulletin(ic.id, :period) AS bulletin FROM etudiant e JOIN utilisateur u ON u.id=e.utilisateur_id JOIN inscription_classe ic ON ic.etudiant_id=e.id WHERE e.matricule=:matricule AND ic.statut_inscription='VALIDEE'");
        $stmt->execute(['matricule' => $parts[2], 'period' => $period]);
        $row = $stmt->fetch();
        if (!$row) jsonResponse(['message' => 'Étudiant introuvable'], 404);
        $row['bulletin'] = json_decode($row['bulletin'], true);
        jsonResponse($row);
    }

    if (($parts[1] ?? '') === 'notes' && $method === 'POST' && !isset($parts[2])) {
        $input = body();
        foreach (['evaluation_id', 'inscription_ue_id', 'valeur_note'] as $field) if (!array_key_exists($field, $input)) jsonResponse(['message' => "Champ requis : $field"], 422);
        if (!is_numeric($input['valeur_note']) || $input['valeur_note'] < 0 || $input['valeur_note'] > 100) jsonResponse(['message' => 'La note doit être comprise entre 0 et 100'], 422);
        db()->exec("SELECT set_config('gnu.acteur_id', (SELECT id::text FROM utilisateur WHERE role='ENSEIGNANT' ORDER BY id LIMIT 1), false), set_config('gnu.motif', 'Saisie de note depuis la première itération', false), set_config('gnu.origine', 'UTILISATEUR', false)");
        $stmt = db()->prepare("INSERT INTO note(evaluation_id, inscription_ue_id, valeur_note, situation, statut_note) VALUES (:evaluation_id,:inscription_ue_id,:valeur_note,'NUMERIQUE','BROUILLON') RETURNING id");
        $stmt->execute(['evaluation_id' => $input['evaluation_id'], 'inscription_ue_id' => $input['inscription_ue_id'], 'valeur_note' => $input['valeur_note']]);
        jsonResponse(['id' => (int) $stmt->fetchColumn(), 'status' => 'BROUILLON'], 201);
    }

    if (($parts[1] ?? '') === 'notes' && isset($parts[2]) && ($parts[3] ?? '') === 'validate' && $method === 'POST') {
        $pdo = db(); $pdo->beginTransaction();
        $pdo->exec("SELECT set_config('gnu.acteur_id', (SELECT id::text FROM utilisateur WHERE role='ENSEIGNANT' ORDER BY id LIMIT 1), true)");
        $pdo->exec("SELECT set_config('gnu.motif', 'Validation de note depuis la première itération', true), set_config('gnu.origine', 'UTILISATEUR', true)");
        $stmt = $pdo->prepare("UPDATE note SET statut_note='VALIDEE', validateur_id=(SELECT id FROM utilisateur WHERE role='ENSEIGNANT' ORDER BY id LIMIT 1), date_validation=statement_timestamp() WHERE id=:id AND statut_note='BROUILLON' RETURNING id, statut_note");
        $stmt->execute(['id' => $parts[2]]); $row = $stmt->fetch();
        if (!$row) { $pdo->rollBack(); jsonResponse(['message' => 'Note inexistante ou déjà validée'], 404); }
        $pdo->commit(); jsonResponse($row);
    }

    jsonResponse(['message' => 'Route introuvable'], 404);
} catch (Throwable $e) {
    jsonResponse(['message' => 'Erreur serveur', 'detail' => $e->getMessage()], 500);
}
