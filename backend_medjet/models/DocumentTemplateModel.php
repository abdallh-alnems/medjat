<?php

final class DocumentTemplateModel {
    /**
     * Built-in templates seeded once per tenant. Bodies use {{placeholders}}
     * resolved by LetterPdfService::buildVariables().
     */
    public const DEFAULTS = [
        [
            'template_key' => 'salary_certificate',
            'name_ar' => 'شهادة راتب',
            'name_en' => 'Salary Certificate',
            'sort_order' => 1,
            'body_ar' => "تشهد {{company_name}} بأن الموظف/ {{employee_name}}، حامل الهوية رقم {{national_id}}، يعمل لدينا بوظيفة {{job_title}} اعتباراً من {{hire_date}}، وأن راتبه الأساسي الشهري قدره {{base_salary}} {{currency}}.\n\nوقد أُعطيت له هذه الشهادة بناءً على طلبه دون أدنى مسؤولية على الشركة تجاه الغير.\n\nوتفضلوا بقبول فائق الاحترام،",
        ],
        [
            'template_key' => 'employment_verification',
            'name_ar' => 'تعريف بالعمل',
            'name_en' => 'Employment Verification',
            'sort_order' => 2,
            'body_ar' => "إلى من يهمه الأمر\n\nتشهد {{company_name}} بأن الموظف/ {{employee_name}}، حامل الهوية رقم {{national_id}}، يعمل لدينا بوظيفة {{job_title}} في فرع {{branch_name}} منذ تاريخ {{hire_date}}، وما زال على رأس عمله حتى تاريخه.\n\nوقد مُنحت له هذه الشهادة بناءً على طلبه.",
        ],
        [
            'template_key' => 'bank_letter',
            'name_ar' => 'خطاب تعريف بنكي',
            'name_en' => 'Bank Introduction Letter',
            'sort_order' => 3,
            'body_ar' => "السادة/ {{bank_name}}			المحترمون\n\nتحية طيبة وبعد،\n\nنفيدكم بأن الموظف/ {{employee_name}}، حامل الهوية رقم {{national_id}}، يعمل لدى {{company_name}} بوظيفة {{job_title}}، براتب أساسي شهري قدره {{base_salary}} {{currency}}، اعتباراً من {{hire_date}}.\n\nنأمل تقديم التسهيلات اللازمة له، علماً بأن هذا الخطاب لا يُرتب أي التزام مالي على الشركة.\n\nوتفضلوا بقبول فائق الاحترام،",
        ],
    ];

    /** Seed the default system templates for a tenant if they have none yet. */
    public static function ensureDefaults(int $tenantId): void {
        $existing = Database::fetchOne(
            "SELECT COUNT(*) AS c FROM document_templates WHERE tenant_id = ? AND is_system = 1",
            [$tenantId]
        );
        if ((int) ($existing['c'] ?? 0) > 0) {
            return;
        }
        foreach (self::DEFAULTS as $tpl) {
            Database::execute(
                "INSERT INTO document_templates
                    (tenant_id, template_key, name_ar, name_en, body_ar, body_en, is_system, is_active, sort_order)
                 VALUES (?, ?, ?, ?, ?, NULL, 1, 1, ?)",
                [$tenantId, $tpl['template_key'], $tpl['name_ar'], $tpl['name_en'], $tpl['body_ar'], $tpl['sort_order']]
            );
        }
    }

    public static function getByTenant(int $tenantId, bool $activeOnly = false): array {
        $sql = "SELECT * FROM document_templates WHERE tenant_id = ?";
        $params = [$tenantId];
        if ($activeOnly) {
            $sql .= " AND is_active = 1";
        }
        $sql .= " ORDER BY sort_order ASC, id ASC";
        return Database::fetchAll($sql, $params);
    }

    public static function find(int $id, int $tenantId): ?array {
        return Database::fetchOne(
            "SELECT * FROM document_templates WHERE id = ? AND tenant_id = ? LIMIT 1",
            [$id, $tenantId]
        );
    }

    public static function create(int $tenantId, array $data): int {
        Database::execute(
            "INSERT INTO document_templates
                (tenant_id, template_key, name_ar, name_en, body_ar, body_en, is_system, is_active, sort_order)
             VALUES (?, NULL, ?, ?, ?, ?, 0, ?, ?)",
            [
                $tenantId,
                $data['name_ar'],
                $data['name_en'] ?? null,
                $data['body_ar'],
                $data['body_en'] ?? null,
                isset($data['is_active']) ? (int) $data['is_active'] : 1,
                (int) ($data['sort_order'] ?? 0),
            ]
        );
        return (int) Database::lastInsertId();
    }

    public static function update(int $id, int $tenantId, array $data): void {
        $allowed = ['name_ar', 'name_en', 'body_ar', 'body_en', 'is_active', 'sort_order'];
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
            "UPDATE document_templates SET " . implode(', ', $fields) . " WHERE id = ? AND tenant_id = ?",
            $values
        );
    }

    /** Custom templates only (system templates cannot be deleted). */
    public static function delete(int $id, int $tenantId): bool {
        $affected = Database::execute(
            "DELETE FROM document_templates WHERE id = ? AND tenant_id = ? AND is_system = 0",
            [$id, $tenantId]
        );
        return $affected > 0;
    }
}
