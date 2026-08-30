<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'biometric_enroll');

$input = $auth['input'];
$employeeId = (int) ($input['employee_id'] ?? 0);
Validator::required($employeeId, 'employee_id');

$emp = EmployeeModel::findById($employeeId, $tenantId);
if (!$emp) Response::fail('Employee not found', 404, 'employee_not_found');
PermissionMiddleware::checkBranchAccess($auth, (int) $emp['branch_id']);

$embedding = $input['embedding'] ?? null;
$imageBase64 = $input['image_base64'] ?? null;
$qualityScore = (float) ($input['quality_score'] ?? 0);

Validator::required($embedding, 'embedding');

// A malformed vector would be stored happily and then fail every single
// check-in with an opaque error, so it is rejected at the door.
$vector = FaceMatchService::parseEmbedding($embedding);
if ($vector === null) {
    Response::fail('embedding must be a numeric vector of 128, 192 or 512 finite values', 422, 'invalid_embedding');
}

$photoUrl = BiometricEnrollment::storeReferencePhoto($imageBase64, $tenantId, $employeeId);

BiometricModel::enrollFace(
    $employeeId,
    $tenantId,
    json_encode($vector),
    $photoUrl,
    $qualityScore,
    $input['model_version'] ?? FaceMatchService::MODEL_VERSION,
    count($vector)
);

AuditLogModel::log($tenantId, $auth['admin_id'], 'biometric.enroll_face', 'employee', $employeeId);

Response::success([
    'employee_id' => $employeeId,
    'status' => 'face_enrolled',
], 201);
