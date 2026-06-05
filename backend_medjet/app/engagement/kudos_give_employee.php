<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateEmployee(db());

$tenantId = $auth['tenant_id'];
$employeeId = $auth['employee_id'];

$input = $auth['input'];
$recipientId = (int) ($input['recipient_employee_id'] ?? 0);
$badge = $input['badge'] ?? 'thank_you';
$message = trim((string) ($input['message'] ?? ''));
$visibility = $input['visibility'] ?? 'public';

Validator::required($recipientId, 'recipient_employee_id');
Validator::required($message, 'message');
$badge = Validator::enum($badge, KudosModel::BADGES, 'badge');
$visibility = Validator::enum($visibility, KudosModel::VISIBILITY, 'visibility');

if ($recipientId === $employeeId) {
    Response::fail('You cannot give kudos to yourself', 422);
}

$recipient = EmployeeModel::findById($recipientId, $tenantId);
if (!$recipient) {
    Response::notFound('Employee');
}

$data = [
    'recipient_employee_id' => $recipientId,
    'badge' => $badge,
    'message' => $message,
    'visibility' => $visibility,
];

$id = KudosModel::create($tenantId, $data, null, $employeeId);
KudosModel::notifyRecipient($tenantId, $id, $recipientId, $badge);

Response::success(['id' => $id, 'message' => 'Kudos sent'], 201);
