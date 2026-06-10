<?php

/**
 * Best-effort notification to a tenant's managers about something an employee
 * did in the mobile app (submitted a document, requested leave / a break, …).
 *
 * Mirrors EmployeeActivationAlert: pushes to managers' devices AND persists an
 * in-app notification row per manager so it shows in their list even if the
 * push isn't delivered. Never throws into the caller's flow.
 *
 * This is the employee→management counterpart to NotificationService::
 * sendToEmployee(), which the admin-side actions (approve / reject / verify)
 * already use to notify the employee. Together they give two-way alerts.
 */
final class ManagerAlert {
    /**
     * @param string $type One of the notifications.type ENUM values
     *                     ('leave', 'approval', 'general', …).
     * @param array  $data Extra push payload (string-coerced by FCM layer).
     */
    public static function notify(
        int $tenantId,
        string $type,
        string $titleAr,
        string $title,
        string $bodyAr,
        string $body,
        ?int $employeeId = null,
        array $data = []
    ): void {
        try {
            if ($tenantId <= 0) {
                return;
            }

            $payload = array_merge(['type' => $type], $data);
            if ($employeeId) {
                $payload['employee_id'] = (string) $employeeId;
            }
            $dataJson = json_encode($payload, JSON_UNESCAPED_UNICODE);

            // Push to managers' devices.
            NotificationService::sendToTenantManagers($tenantId, $titleAr, $bodyAr, $payload);

            // Persist an in-app row for each manager.
            $managers = Database::fetchAll(
                "SELECT id FROM admins
                 WHERE tenant_id = ? AND role NOT IN ('employee', 'pending')",
                [$tenantId]
            );

            foreach ($managers as $manager) {
                Database::execute(
                    "INSERT INTO notifications
                       (tenant_id, admin_id, employee_id, type, title, title_ar, body, body_ar, data, sent_via)
                     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'push,in_app')",
                    [
                        $tenantId,
                        (int) $manager['id'],
                        $employeeId ?: null,
                        $type,
                        $title,
                        $titleAr,
                        $body,
                        $bodyAr,
                        $dataJson,
                    ]
                );
            }
        } catch (Throwable $e) {
            error_log('ManagerAlert error: ' . $e->getMessage());
        }
    }
}
