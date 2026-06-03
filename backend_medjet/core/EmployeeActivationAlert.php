<?php

/**
 * Notifies a tenant's managers when an employee signs in to the mobile app.
 * Fires on every login; the message distinguishes the first activation (the
 * account being linked) from subsequent logins. Mirrors LoginAlertService:
 * best-effort, never throws into the login flow.
 */
final class EmployeeActivationAlert {
    public static function notify(array $employee, bool $isFirstActivation = false): void {
        try {
            $tenantId = (int) ($employee['tenant_id'] ?? 0);
            if ($tenantId <= 0) {
                return;
            }

            $name = trim((string) ($employee['name'] ?? '')) ?: 'موظف';
            $employeeId = (int) ($employee['id'] ?? 0);
            $branchId = !empty($employee['branch_id']) ? (int) $employee['branch_id'] : null;
            $branchName = (string) ($employee['branch_name'] ?? '');
            $branchSuffixAr = $branchName !== '' ? " ({$branchName})" : '';
            $branchSuffix = $branchName !== '' ? " ({$branchName})" : '';

            if ($isFirstActivation) {
                $titleAr = 'تفعيل حساب موظف';
                $title = 'Employee account activated';
                $bodyAr = "{$name} قام بتفعيل حسابه وتسجيل الدخول إلى التطبيق.{$branchSuffixAr}";
                $body = "{$name} activated their account and signed in to the app.{$branchSuffix}";
                $eventType = 'employee_activated';
            } else {
                $titleAr = 'تسجيل دخول موظف';
                $title = 'Employee signed in';
                $bodyAr = "{$name} سجّل الدخول إلى التطبيق.{$branchSuffixAr}";
                $body = "{$name} signed in to the app.{$branchSuffix}";
                $eventType = 'employee_login';
            }

            $data = [
                'type' => $eventType,
                'employee_id' => (string) $employeeId,
                'branch_id' => $branchId !== null ? (string) $branchId : '',
            ];
            $dataJson = json_encode($data, JSON_UNESCAPED_UNICODE);

            // Push to the managers' devices.
            NotificationService::sendToTenantManagers($tenantId, $titleAr, $bodyAr, $data);

            // Persist an in-app notification row for each manager so it appears
            // in their notification list even if the push isn't delivered.
            $managers = Database::fetchAll(
                "SELECT id FROM admins
                 WHERE tenant_id = ? AND role NOT IN ('employee', 'pending')",
                [$tenantId]
            );

            foreach ($managers as $manager) {
                Database::execute(
                    "INSERT INTO notifications
                       (tenant_id, admin_id, employee_id, type, title, title_ar, body, body_ar, data, sent_via)
                     VALUES (?, ?, ?, 'system', ?, ?, ?, ?, ?, 'push,in_app')",
                    [
                        $tenantId,
                        (int) $manager['id'],
                        $employeeId > 0 ? $employeeId : null,
                        $title,
                        $titleAr,
                        $body,
                        $bodyAr,
                        $dataJson,
                    ]
                );
            }
        } catch (Throwable $e) {
            error_log('EmployeeActivationAlert error: ' . $e->getMessage());
        }
    }
}
