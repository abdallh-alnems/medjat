<?php

final class OnboardingModel {
    public const TASK_TYPES = ['document', 'asset', 'account', 'generic'];
    public const TASK_STATUSES = ['pending', 'completed', 'skipped'];

    private const DEFAULT_TEMPLATES = [
        ['title' => 'Collect required documents', 'title_ar' => 'تجميع المستندات المطلوبة', 'task_type' => 'document', 'sort_order' => 1],
        ['title' => 'Hand over equipment / custody', 'title_ar' => 'تسليم العهد والأجهزة', 'task_type' => 'asset', 'sort_order' => 2],
        ['title' => 'Create system & email accounts', 'title_ar' => 'إنشاء حسابات النظام والبريد', 'task_type' => 'account', 'sort_order' => 3],
        ['title' => 'Sign employment contract', 'title_ar' => 'توقيع عقد العمل', 'task_type' => 'generic', 'sort_order' => 4],
        ['title' => 'Orientation & workspace setup', 'title_ar' => 'التعريف وتجهيز مكان العمل', 'task_type' => 'generic', 'sort_order' => 5],
    ];

    public static function listTemplates(int $tenantId, bool $activeOnly = false): array {
        $sql = "SELECT * FROM onboarding_templates WHERE tenant_id = ?";
        $params = [$tenantId];
        if ($activeOnly) {
            $sql .= " AND is_active = 1";
        }
        $sql .= " ORDER BY sort_order ASC, id ASC";
        return Database::fetchAll($sql, $params);
    }

    public static function createTemplate(int $tenantId, array $data): int {
        Database::execute(
            "INSERT INTO onboarding_templates (tenant_id, title, title_ar, task_type, description, sort_order, is_active)
             VALUES (?, ?, ?, ?, ?, ?, ?)",
            [
                $tenantId,
                $data['title'],
                $data['title_ar'] ?? null,
                $data['task_type'] ?? 'generic',
                $data['description'] ?? null,
                (int) ($data['sort_order'] ?? 0),
                isset($data['is_active']) ? (int) $data['is_active'] : 1,
            ]
        );
        return (int) Database::lastInsertId();
    }

    public static function updateTemplate(int $id, int $tenantId, array $data): void {
        $allowed = ['title', 'title_ar', 'task_type', 'description', 'sort_order', 'is_active'];
        $fields = [];
        $values = [];
        foreach ($allowed as $key) {
            if (array_key_exists($key, $data)) {
                $fields[] = "`{$key}` = ?";
                $values[] = $data[$key];
            }
        }
        if (empty($fields)) {
            return;
        }
        $values[] = $id;
        $values[] = $tenantId;
        Database::execute(
            "UPDATE onboarding_templates SET " . implode(', ', $fields) . " WHERE id = ? AND tenant_id = ?",
            $values
        );
    }

    public static function deleteTemplate(int $id, int $tenantId): bool {
        return Database::execute(
            "DELETE FROM onboarding_templates WHERE id = ? AND tenant_id = ?",
            [$id, $tenantId]
        ) > 0;
    }

    public static function ensureDefaults(int $tenantId): void {
        $existing = Database::fetchOne(
            "SELECT COUNT(*) AS c FROM onboarding_templates WHERE tenant_id = ?",
            [$tenantId]
        );
        if ((int) ($existing['c'] ?? 0) > 0) {
            return;
        }
        foreach (self::DEFAULT_TEMPLATES as $tpl) {
            Database::execute(
                "INSERT INTO onboarding_templates (tenant_id, title, title_ar, task_type, sort_order, is_active)
                 VALUES (?, ?, ?, ?, ?, 1)",
                [$tenantId, $tpl['title'], $tpl['title_ar'], $tpl['task_type'], $tpl['sort_order']]
            );
        }
    }

    public static function generateForEmployee(int $tenantId, int $employeeId): int {
        $existing = Database::fetchOne(
            "SELECT COUNT(*) AS c FROM onboarding_tasks WHERE tenant_id = ? AND employee_id = ?",
            [$tenantId, $employeeId]
        );
        if ((int) ($existing['c'] ?? 0) > 0) {
            return 0;
        }

        $templates = self::listTemplates($tenantId, true);
        $count = 0;
        foreach ($templates as $tpl) {
            Database::execute(
                "INSERT INTO onboarding_tasks (tenant_id, employee_id, template_id, title, task_type, sort_order, status)
                 VALUES (?, ?, ?, ?, ?, ?, 'pending')",
                [$tenantId, $employeeId, $tpl['id'], $tpl['title'], $tpl['task_type'], $tpl['sort_order']]
            );
            $count++;
        }
        return $count;
    }

    public static function listForEmployee(int $tenantId, int $employeeId): array {
        return Database::fetchAll(
            "SELECT * FROM onboarding_tasks WHERE tenant_id = ? AND employee_id = ? ORDER BY sort_order ASC, id ASC",
            [$tenantId, $employeeId]
        );
    }

    public static function setTaskStatus(int $taskId, int $tenantId, string $status, int $adminId): void {
        if ($status === 'completed') {
            Database::execute(
                "UPDATE onboarding_tasks SET status = ?, completed_by = ?, completed_at = NOW() WHERE id = ? AND tenant_id = ?",
                [$status, $adminId, $taskId, $tenantId]
            );
        } else {
            Database::execute(
                "UPDATE onboarding_tasks SET status = ?, completed_by = NULL, completed_at = NULL WHERE id = ? AND tenant_id = ?",
                [$status, $taskId, $tenantId]
            );
        }
    }

    public static function addTask(int $tenantId, int $employeeId, array $data): int {
        Database::execute(
            "INSERT INTO onboarding_tasks (tenant_id, employee_id, title, task_type, sort_order, status)
             VALUES (?, ?, ?, ?, ?, 'pending')",
            [
                $tenantId,
                $employeeId,
                $data['title'],
                $data['task_type'] ?? 'generic',
                (int) ($data['sort_order'] ?? 0),
            ]
        );
        return (int) Database::lastInsertId();
    }

    public static function progress(int $tenantId, int $employeeId): array {
        $row = Database::fetchOne(
            "SELECT
                COUNT(*) AS total,
                SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) AS completed
             FROM onboarding_tasks
             WHERE tenant_id = ? AND employee_id = ?",
            [$tenantId, $employeeId]
        );
        $total = (int) ($row['total'] ?? 0);
        $completed = (int) ($row['completed'] ?? 0);
        $percent = $total > 0 ? round(($completed / $total) * 100) : 0;
        return ['total' => $total, 'completed' => $completed, 'percent' => $percent];
    }
}
