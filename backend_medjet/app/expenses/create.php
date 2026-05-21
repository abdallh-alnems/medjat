<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_payroll');

$input = $auth['input'];
$employeeId = (int) ($input['employee_id'] ?? 0);
$category = $input['category'] ?? 'other';
$amount = (float) ($input['amount'] ?? 0);
$expenseDate = $input['expense_date'] ?? null;
$description = $input['description'] ?? null;
$currency = $input['currency'] ?? 'SAR';
$receiptUrl = $input['receipt_url'] ?? null;

Validator::required($employeeId, 'employee_id');
Validator::required($amount, 'amount');
Validator::numeric($amount, 'amount', 0.01);
Validator::required($expenseDate, 'expense_date');
Validator::date($expenseDate, 'expense_date');
$category = Validator::enum($category, ExpenseModel::CATEGORIES, 'category');

$employee = EmployeeModel::findById($employeeId, $tenantId);
if (!$employee) {
    Response::notFound('Employee');
}

$id = ExpenseModel::create(
    $tenantId, $employeeId, $category, $amount,
    $expenseDate, $description, $currency, $receiptUrl, $auth['admin_id']
);

AuditLogModel::log($tenantId, $auth['admin_id'], 'expense.create', 'expense', $id, ['amount' => $amount, 'category' => $category]);

Response::success(['id' => $id, 'message' => 'Expense claim created']);
