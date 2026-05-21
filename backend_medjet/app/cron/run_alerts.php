<?php
require_once __DIR__ . '/../../config/bootstrap.php';

$key = $_GET['key'] ?? '';
$expected = getenv('CRON_SECRET') ?: '';
if ($expected === '' || $key !== $expected) {
    http_response_code(403);
    header('Content-Type: application/json');
    echo json_encode(['error' => 'Forbidden']);
    exit;
}

$counts = [
    'late_absence' => 0,
    'missing_checkout' => 0,
    'document_expiry' => 0,
    'compliance_expiry' => 0,
];

$tenants = Database::fetchAll(
    "SELECT id FROM tenants WHERE status = 'active'"
);

$today = date('Y-m-d');

foreach ($tenants as $tenant) {
    $tenantId = (int) $tenant['id'];

    _checkLateAbsence($tenantId, $today, $counts);
    _checkMissingCheckout($tenantId, $today, $counts);
    _checkDocumentExpiry($tenantId, $counts);
    _checkComplianceExpiry($tenantId, $counts);
}

header('Content-Type: application/json');
echo json_encode([
    'status' => 'success',
    'date' => $today,
    'alerts_sent' => $counts,
]);

function _checkLateAbsence(int $tenantId, string $today, array &$counts): void
{
    $rows = Database::fetchAll(
        "SELECT a.employee_id, a.branch_id, a.late_minutes, a.status,
                e.name as employee_name, b.name as branch_name
         FROM attendance a
         JOIN employees e ON e.id = a.employee_id
         LEFT JOIN branches b ON b.id = a.branch_id
         WHERE a.tenant_id = ? AND a.date = ?
           AND (a.late_minutes > 0 OR a.status = 'absent')",
        [$tenantId, $today]
    );

    foreach ($rows as $row) {
        $empName = $row['employee_name'];
        $branchId = $row['branch_id'] ? (int) $row['branch_id'] : null;

        if ($row['status'] === 'absent') {
            $bodyAr = "غياب الموظف {$empName} اليوم";
            $bodyEn = "Employee {$empName} is absent today";
        } else {
            $mins = (int) $row['late_minutes'];
            $bodyAr = "تأخر الموظف {$empName} {$mins} دقيقة";
            $bodyEn = "Employee {$empName} is {$mins} min late";
        }

        $recipients = SmartAlertService::recipientsForBranch(
            $tenantId, $branchId, 'manage_attendance'
        );

        foreach ($recipients as $rid) {
            SmartAlertService::dispatch(
                $rid,
                'late_absence',
                'attendance',
                'تنبيه حضور',
                $bodyAr,
                'Attendance Alert',
                $bodyEn,
                [
                    'employee_id' => (int) $row['employee_id'],
                    'employee_name' => $empName,
                    'date' => $today,
                    'late_minutes' => (int) $row['late_minutes'],
                    'status' => $row['status'],
                ],
                "late:{$row['employee_id']}:{$today}"
            );
            $counts['late_absence']++;
        }
    }
}

function _checkMissingCheckout(int $tenantId, string $today, array &$counts): void
{
    $branches = Database::fetchAll(
        "SELECT id, work_end_time FROM branches WHERE tenant_id = ?",
        [$tenantId]
    );

    $branchEndTimes = [];
    $defaultEndTime = '18:00:00';
    foreach ($branches as $br) {
        $branchEndTimes[(int) $br['id']] = $br['work_end_time'] ?: $defaultEndTime;
    }

    $rows = Database::fetchAll(
        "SELECT a.employee_id, a.branch_id, a.check_in_time,
                e.name as employee_name
         FROM attendance a
         JOIN employees e ON e.id = a.employee_id
         WHERE a.tenant_id = ? AND a.date = ?
           AND a.check_in_time IS NOT NULL
           AND a.check_out_time IS NULL
           AND a.status IN ('present','leave','holiday','weekly_off')",
        [$tenantId, $today]
    );

    $now = date('H:i:s');

    foreach ($rows as $row) {
        $branchId = $row['branch_id'] ? (int) $row['branch_id'] : null;
        $endTime = $branchId ? ($branchEndTimes[$branchId] ?? $defaultEndTime) : $defaultEndTime;

        if ($now < $endTime) {
            continue;
        }

        $empName = $row['employee_name'];
        $recipients = SmartAlertService::recipientsForBranch(
            $tenantId, $branchId, 'manage_attendance'
        );

        foreach ($recipients as $rid) {
            SmartAlertService::dispatch(
                $rid,
                'missing_checkout',
                'attendance',
                'حضور بدون انصراف',
                "الموظف {$empName} سجّل حضور ولم يسجّل انصراف",
                'Missing Checkout',
                "Employee {$empName} checked in but has not checked out",
                [
                    'employee_id' => (int) $row['employee_id'],
                    'employee_name' => $empName,
                    'date' => $today,
                ],
                "nocheckout:{$row['employee_id']}:{$today}"
            );
            $counts['missing_checkout']++;
        }
    }
}

function _checkDocumentExpiry(int $tenantId, array &$counts): void
{
    $documents = DocumentModel::getExpiringSoon($tenantId, 30);

    foreach ($documents as $doc) {
        $employeeName = $doc['employee_name'];
        $docName = $doc['document_name'];
        $expiresAt = $doc['expires_at'];
        $branchId = $doc['branch_id'] ? (int) $doc['branch_id'] : null;

        $recipients = SmartAlertService::recipientsForBranch(
            $tenantId, $branchId, 'manage_documents'
        );

        foreach ($recipients as $rid) {
            SmartAlertService::dispatch(
                $rid,
                'document_expiry',
                'general',
                'وثيقة تنتهي قريباً',
                "وثيقة \"{$docName}\" للموظف {$employeeName} تنتهي بتاريخ {$expiresAt}",
                'Document Expiring Soon',
                "Document \"{$docName}\" for {$employeeName} expires on {$expiresAt}",
                [
                    'employee_document_id' => (int) $doc['id'],
                    'employee_id' => (int) $doc['employee_id'],
                    'employee_name' => $employeeName,
                    'document_name' => $docName,
                    'expires_at' => $expiresAt,
                ],
                "docexp:{$doc['id']}"
            );
            $counts['document_expiry']++;
        }
    }
}

function _checkComplianceExpiry(int $tenantId, array &$counts): void
{
    // Credential => [Arabic label, English label]
    static $labels = [
        'iqama'            => ['الإقامة', 'Iqama / Residency'],
        'passport'         => ['جواز السفر', 'Passport'],
        'work_permit'      => ['رخصة العمل', 'Work Permit'],
        'contract'         => ['عقد العمل', 'Employment Contract'],
        'health_insurance' => ['التأمين الصحي', 'Health Insurance'],
    ];

    $rows = EmployeeModel::getExpiringCompliance($tenantId, 30, null, true);

    foreach ($rows as $row) {
        $credential = $row['credential'];
        [$labelAr, $labelEn] = $labels[$credential] ?? [$credential, $credential];
        $empName = $row['employee_name'];
        $expiresAt = $row['expires_at'];
        $branchId = $row['branch_id'];

        if ($row['is_expired']) {
            $bodyAr = "{$labelAr} للموظف {$empName} منتهية منذ {$expiresAt}";
            $bodyEn = "{$labelEn} for {$empName} expired on {$expiresAt}";
        } else {
            $days = $row['days_left'];
            $bodyAr = "{$labelAr} للموظف {$empName} تنتهي خلال {$days} يوم ({$expiresAt})";
            $bodyEn = "{$labelEn} for {$empName} expires in {$days} days ({$expiresAt})";
        }

        $recipients = SmartAlertService::recipientsForBranch(
            $tenantId, $branchId, 'manage_employees'
        );

        foreach ($recipients as $rid) {
            SmartAlertService::dispatch(
                $rid,
                'compliance_expiry',
                'general',
                'وثيقة رسمية تنتهي قريباً',
                $bodyAr,
                'Credential Expiring Soon',
                $bodyEn,
                [
                    'employee_id' => $row['employee_id'],
                    'employee_name' => $empName,
                    'credential' => $credential,
                    'expires_at' => $expiresAt,
                    'days_left' => $row['days_left'],
                    'is_expired' => $row['is_expired'],
                ],
                "compexp:{$row['employee_id']}:{$credential}"
            );
            $counts['compliance_expiry']++;
        }
    }
}
