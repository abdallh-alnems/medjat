<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();

$token = $_SERVER['HTTP_X_STATION_TOKEN'] ?? null;
if (!$token) Response::fail('Station token is required', 401);

$station = AttendanceStationModel::findByToken($token);
if (!$station) Response::fail('Invalid station token', 401);
if ($station['is_locked']) Response::fail('Station is locked', 403);

$input = json_decode(file_get_contents('php://input'), true) ?: [];
$embedding = $input['embedding'] ?? null;
Validator::required($embedding, 'embedding');

if (!is_array($embedding)) {
    Response::fail('embedding must be an array of numbers', 400);
}

$embedding = array_map('floatval', $embedding);
$embeddingNorm = _kiosk_cosine_norm($embedding);
if ($embeddingNorm < 1e-6) {
    Response::fail('Invalid embedding (zero vector)', 400);
}

$threshold = (float) ($station['station_confidence_threshold'] ?? 0.85);

$employees = BiometricModel::findEmployeesForBranch($station['branch_id'], $station['tenant_id']);

$bestMatch = null;
$bestScore = 0.0;

foreach ($employees as $emp) {
    if (empty($emp['face_embedding'])) continue;

    $storedEmbedding = json_decode($emp['face_embedding'], true);
    if (!is_array($storedEmbedding)) continue;

    $storedEmbedding = array_map('floatval', $storedEmbedding);
    $score = _kiosk_cosine_similarity($embedding, $storedEmbedding, $embeddingNorm);

    if ($score > $bestScore) {
        $bestScore = $score;
        $bestMatch = $emp;
    }
}

if ($bestMatch === null || $bestScore < $threshold) {
    $failureReason = $bestMatch === null ? 'no_enrolled_faces' : 'low_confidence';

    StationRecognitionLogModel::log(
        $station['id'],
        $station['branch_id'],
        $station['tenant_id'],
        $bestMatch ? (int) $bestMatch['id'] : null,
        'face',
        'no_match',
        $bestScore,
        $failureReason,
        null,
        null,
        null
    );

    Response::success([
        'matched' => false,
        'confidence' => round($bestScore, 4),
        'employee_id' => null,
        'employee_name' => null,
    ]);
}

Response::success([
    'matched' => true,
    'confidence' => round($bestScore, 4),
    'employee_id' => (int) $bestMatch['id'],
    'employee_name' => $bestMatch['name'],
]);

function _kiosk_cosine_similarity(array $a, array $b, float $normA = 0.0): float {
    $len = min(count($a), count($b));
    if ($len === 0) return 0.0;

    $dot = 0.0;
    $normB = 0.0;
    for ($i = 0; $i < $len; $i++) {
        $dot += $a[$i] * $b[$i];
        $normB += $b[$i] * $b[$i];
    }
    $normB = sqrt($normB);
    if ($normB < 1e-6) return 0.0;

    if ($normA < 1e-6) {
        $normA = _kiosk_cosine_norm($a);
    }

    return $dot / ($normA * $normB);
}

function _kiosk_cosine_norm(array $v): float {
    $sum = 0.0;
    foreach ($v as $val) $sum += $val * $val;
    return sqrt($sum);
}
