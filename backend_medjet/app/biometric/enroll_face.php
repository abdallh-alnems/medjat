<?php
require_once __DIR__ . '/../../config/bootstrap.php';

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

$photoUrl = null;
if ($imageBase64) {
    $uploadDir = __DIR__ . '/../../uploads/faces/';
    if (!is_dir($uploadDir)) mkdir($uploadDir, 0755, true);
    $fileName = 'face_' . $tenantId . '_' . $employeeId . '_' . time() . '.jpg';
    $imageData = base64_decode(preg_replace('#^data:image/\w+;base64,#i', '', $imageBase64));
    if ($imageData) {
        file_put_contents($uploadDir . $fileName, $imageData);
        $photoUrl = 'uploads/faces/' . $fileName;
    }
}

BiometricModel::enrollFace($employeeId, $tenantId, is_array($embedding) ? json_encode($embedding) : $embedding, $photoUrl, $qualityScore);

AuditLogModel::log($tenantId, $auth['admin_id'], 'biometric.enroll_face', 'employee', $employeeId);

Response::success([
    'employee_id' => $employeeId,
    'status' => 'face_enrolled',
], 201);
