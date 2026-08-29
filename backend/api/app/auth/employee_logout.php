<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

Auth::requirePost();

$token = $_SERVER['HTTP_X_EMPLOYEE_TOKEN'] ?? null;
if ($token) {
    EmployeeAuthTokenModel::revokeByPlain($token, 'employee_logout');
}

Response::success(['success' => true]);
