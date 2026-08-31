<?php

declare(strict_types=1);

namespace App\Modules\Cron\Services;

use App\Modules\Audit\Domain\AuditLog;
use App\Modules\Employees\Domain\ComplianceExpiry;
use App\Modules\Notifications\Domain\SmartAlert;
use App\Shared\Time\TenantClock;
use App\Support\Value;
use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Support\Facades\DB;

/**
 * Port of api/app/cron/run_alerts.php.
 *
 * The morning digest: who was late, who never checked out, what expires soon,
 * whose fixed term is ending, and which kiosk has gone dark.
 *
 * Every alert carries a dedupe key, so the same problem produces one notice a
 * day rather than one per run. That matters more than it sounds: an alert
 * stream that repeats is one people learn to swipe away, and then the one that
 * mattered goes with it.
 */
final class RunDailyAlerts
{
    /** How far ahead a fixed term counts as "ending soon". */
    private const EMPLOYMENT_WARNING_DAYS = 7;

    /** How far ahead a credential counts as expiring. */
    private const COMPLIANCE_WINDOW_DAYS = 30;

    /** Silence past this and a tablet that died before the shift goes unnoticed. */
    private const KIOSK_SILENCE_MINUTES = 60;

    /** When nobody has said what time the day ends. */
    private const DEFAULT_END_TIME = '18:00:00';

    /**
     * The credentials this alerts on, in both languages.
     *
     * @var array<string, array{0: string, 1: string}>
     */
    private const CREDENTIAL_LABELS = [
        'iqama' => ['الإقامة', 'Iqama / Residency'],
        'passport' => ['جواز السفر', 'Passport'],
        'work_permit' => ['رخصة العمل', 'Work Permit'],
        'contract' => ['عقد العمل', 'Employment Contract'],
        'health_insurance' => ['التأمين الصحي', 'Health Insurance'],
    ];

    /** @var array<string, int> */
    private array $counts = [
        'late_absence' => 0,
        'missing_checkout' => 0,
        'document_expiry' => 0,
        'compliance_expiry' => 0,
        'employment_ending' => 0,
        'employment_terminated' => 0,
        'kiosk_offline' => 0,
    ];

    public function __construct(private readonly SmartAlert $alerts) {}

    /**
     * @return array{status: string, alerts_sent: array<string, int>}
     */
    public function execute(): array
    {
        $tenants = DB::table('tenants')->where('is_active', 1)->pluck('id');

        foreach ($tenants as $id) {
            $tenantId = Value::int($id);

            // Each company's own clock: "today" and "has the day ended" are
            // different questions in Cairo and in Dubai, and this runs once for
            // all of them.
            $now = TenantClock::now($tenantId);
            $today = $now->format('Y-m-d');

            $this->lateAndAbsent($tenantId, $today);
            $this->missingCheckout($tenantId, $today, $now->format('H:i:s'));
            $this->documentExpiry($tenantId);
            $this->complianceExpiry($tenantId);
            $this->employmentEnding($tenantId, $today);
            $this->kioskOffline($tenantId);
        }

        return ['status' => 'success', 'alerts_sent' => $this->counts];
    }

    private function lateAndAbsent(int $tenantId, string $today): void
    {
        $rows = DB::table('attendance as a')
            ->join('employees as e', 'e.id', '=', 'a.employee_id')
            ->where('a.tenant_id', $tenantId)->where('a.date', $today)
            ->where(function (QueryBuilder $q): void {
                $q->where('a.late_minutes', '>', 0)->orWhere('a.status', 'absent');
            })
            ->get(['a.employee_id', 'a.branch_id', 'a.late_minutes', 'a.status', 'e.name as employee_name'])
            ->all();

        foreach ($rows as $row) {
            /** @var array<string, mixed> $entry */
            $entry = (array) $row;

            $employeeId = Value::int($entry['employee_id'] ?? null);
            $name = Value::string($entry['employee_name'] ?? null);
            $minutes = Value::int($entry['late_minutes'] ?? null);
            $status = Value::string($entry['status'] ?? null);

            [$bodyAr, $bodyEn] = $status === 'absent'
                ? ["غياب الموظف {$name} اليوم", "Employee {$name} is absent today"]
                : ["تأخر الموظف {$name} {$minutes} دقيقة", "Employee {$name} is {$minutes} min late"];

            $this->fanOut(
                $tenantId, Value::nullableInt($entry['branch_id'] ?? null), 'manage_attendance',
                'late_absence', 'attendance',
                'تنبيه حضور', $bodyAr, 'Attendance Alert', $bodyEn,
                [
                    'employee_id' => $employeeId,
                    'employee_name' => $name,
                    'date' => $today,
                    'late_minutes' => $minutes,
                    'status' => $status,
                ],
                "late:{$employeeId}:{$today}",
                'late_absence',
            );
        }
    }

    private function missingCheckout(int $tenantId, string $today, string $nowTime): void
    {
        $rows = DB::table('attendance as a')
            ->join('employees as e', 'e.id', '=', 'a.employee_id')
            ->where('a.tenant_id', $tenantId)->where('a.date', $today)
            ->whereNotNull('a.check_in_time')
            ->whereNull('a.check_out_time')
            ->whereIn('a.status', ['present', 'leave', 'holiday', 'weekly_off'])
            ->get(['a.employee_id', 'a.branch_id', 'e.name as employee_name', 'e.work_end_time'])
            ->all();

        foreach ($rows as $row) {
            /** @var array<string, mixed> $entry */
            $entry = (array) $row;

            $endTime = Value::string($entry['work_end_time'] ?? null) ?: self::DEFAULT_END_TIME;

            // Their day is not over yet; there is nothing to report.
            if ($nowTime < $endTime) {
                continue;
            }

            $employeeId = Value::int($entry['employee_id'] ?? null);
            $name = Value::string($entry['employee_name'] ?? null);

            $this->fanOut(
                $tenantId, Value::nullableInt($entry['branch_id'] ?? null), 'manage_attendance',
                'missing_checkout', 'attendance',
                'حضور بدون انصراف',
                "الموظف {$name} سجّل حضور ولم يسجّل انصراف",
                'Missing Checkout',
                "Employee {$name} checked in but has not checked out",
                ['employee_id' => $employeeId, 'employee_name' => $name, 'date' => $today],
                "nocheckout:{$employeeId}:{$today}",
                'missing_checkout',
            );
        }
    }

    private function documentExpiry(int $tenantId): void
    {
        $rows = DB::table('employee_documents as ed')
            ->join('employees as e', 'e.id', '=', 'ed.employee_id')
            ->join('required_documents as rd', 'rd.id', '=', 'ed.required_document_id')
            ->where('ed.tenant_id', $tenantId)
            ->where('ed.status', 'uploaded')
            ->whereNotNull('ed.expires_at')
            // The window each document type asked for, in SQL against the
            // database's own date.
            ->whereRaw(
                'ed.expires_at BETWEEN CURDATE()'
                .' AND DATE_ADD(CURDATE(), INTERVAL COALESCE(rd.notification_days_before, 30) DAY)'
            )
            ->orderBy('ed.expires_at')
            ->get([
                'ed.id', 'ed.employee_id', 'ed.expires_at',
                'e.name as employee_name', 'e.branch_id', 'rd.name as document_name',
            ])
            ->all();

        foreach ($rows as $row) {
            /** @var array<string, mixed> $doc */
            $doc = (array) $row;

            $id = Value::int($doc['id'] ?? null);
            $name = Value::string($doc['employee_name'] ?? null);
            $document = Value::string($doc['document_name'] ?? null);
            $expiresAt = Value::string($doc['expires_at'] ?? null);

            $this->fanOut(
                $tenantId, Value::nullableInt($doc['branch_id'] ?? null), 'manage_documents',
                'document_expiry', 'general',
                'وثيقة تنتهي قريباً',
                "وثيقة \"{$document}\" للموظف {$name} تنتهي بتاريخ {$expiresAt}",
                'Document Expiring Soon',
                "Document \"{$document}\" for {$name} expires on {$expiresAt}",
                [
                    'employee_document_id' => $id,
                    'employee_id' => Value::int($doc['employee_id'] ?? null),
                    'employee_name' => $name,
                    'document_name' => $document,
                    'expires_at' => $expiresAt,
                ],
                "docexp:{$id}",
                'document_expiry',
            );
        }
    }

    private function complianceExpiry(int $tenantId): void
    {
        foreach (ComplianceExpiry::within($tenantId, self::COMPLIANCE_WINDOW_DAYS, null, true) as $row) {
            $credential = Value::string($row['credential'] ?? null);
            [$labelAr, $labelEn] = self::CREDENTIAL_LABELS[$credential] ?? [$credential, $credential];

            $name = Value::string($row['employee_name'] ?? null);
            $expiresAt = Value::string($row['expires_at'] ?? null);
            $employeeId = Value::int($row['employee_id'] ?? null);
            $isExpired = ($row['is_expired'] ?? false) === true;
            $daysLeft = Value::int($row['days_left'] ?? null);

            [$bodyAr, $bodyEn] = $isExpired
                ? [
                    "{$labelAr} للموظف {$name} منتهية منذ {$expiresAt}",
                    "{$labelEn} for {$name} expired on {$expiresAt}",
                ]
                : [
                    "{$labelAr} للموظف {$name} تنتهي خلال {$daysLeft} يوم ({$expiresAt})",
                    "{$labelEn} for {$name} expires in {$daysLeft} days ({$expiresAt})",
                ];

            $this->fanOut(
                $tenantId, Value::nullableInt($row['branch_id'] ?? null), 'manage_employees',
                'compliance_expiry', 'general',
                'وثيقة رسمية تنتهي قريباً', $bodyAr, 'Credential Expiring Soon', $bodyEn,
                [
                    'employee_id' => $employeeId,
                    'employee_name' => $name,
                    'credential' => $credential,
                    'expires_at' => $expiresAt,
                    'days_left' => $daysLeft,
                    'is_expired' => $isExpired,
                ],
                "compexp:{$employeeId}:{$credential}",
                'compliance_expiry',
            );
        }
    }

    /**
     * Fixed-term employment: a warning before the end date, and the
     * termination itself once it has passed.
     */
    private function employmentEnding(int $tenantId, string $today): void
    {
        $upcoming = DB::table('employees')
            ->where('tenant_id', $tenantId)
            ->whereNotNull('auto_terminate_at')
            ->where('auto_terminate_at', '>=', $today)
            ->whereRaw('auto_terminate_at <= DATE_ADD(?, INTERVAL ? DAY)', [$today, self::EMPLOYMENT_WARNING_DAYS])
            ->where('status', '!=', 'terminated')
            ->selectRaw('id, name, branch_id, auto_terminate_at, DATEDIFF(auto_terminate_at, ?) AS days_left', [$today])
            ->get()
            ->all();

        foreach ($upcoming as $row) {
            /** @var array<string, mixed> $employee */
            $employee = (array) $row;

            $id = Value::int($employee['id'] ?? null);
            $name = Value::string($employee['name'] ?? null);
            $endsAt = Value::string($employee['auto_terminate_at'] ?? null);
            $daysLeft = Value::int($employee['days_left'] ?? null);

            $this->fanOut(
                $tenantId, Value::nullableInt($employee['branch_id'] ?? null), 'manage_employees',
                'compliance_expiry', 'general',
                'انتهاء مدة عمل قريباً',
                "تنتهي مدة عمل الموظف {$name} خلال {$daysLeft} يوم ({$endsAt})",
                'Employment Ending Soon',
                "Employment of {$name} ends in {$daysLeft} days ({$endsAt})",
                ['employee_id' => $id, 'employee_name' => $name, 'ends_at' => $endsAt, 'days_left' => $daysLeft],
                "empend:{$id}:{$endsAt}",
                'employment_ending',
            );
        }

        $expired = DB::table('employees')
            ->where('tenant_id', $tenantId)
            ->whereNotNull('auto_terminate_at')
            ->where('auto_terminate_at', '<', $today)
            ->where('status', '!=', 'terminated')
            ->get(['id', 'name', 'branch_id', 'auto_terminate_at'])
            ->all();

        foreach ($expired as $row) {
            /** @var array<string, mixed> $employee */
            $employee = (array) $row;

            $id = Value::int($employee['id'] ?? null);
            $name = Value::string($employee['name'] ?? null);
            $endsAt = Value::string($employee['auto_terminate_at'] ?? null);

            $terminated = DB::table('employees')
                ->where('id', $id)->where('tenant_id', $tenantId)->where('status', '!=', 'terminated')
                ->update([
                    'status' => 'terminated',
                    'terminated_at' => DB::raw('CURDATE()'),
                    'updated_at' => DB::raw('NOW()'),
                ]);

            // The guard is inside the UPDATE, so two overlapping runs cannot
            // both announce the same termination.
            if ($terminated === 0) {
                continue;
            }

            AuditLog::record($tenantId, null, 'employee.auto_terminate', 'employee', $id);

            $this->fanOut(
                $tenantId, Value::nullableInt($employee['branch_id'] ?? null), 'manage_employees',
                'compliance_expiry', 'general',
                'انتهت مدة عمل الموظف',
                "انتهت مدة عمل الموظف {$name} بتاريخ {$endsAt} وتم إنهاء حسابه تلقائياً",
                'Employment Ended',
                "Employment of {$name} ended on {$endsAt}; the account was terminated automatically",
                ['employee_id' => $id, 'employee_name' => $name, 'ended_at' => $endsAt],
                "empterm:{$id}:{$endsAt}",
                null,
            );

            $this->counts['employment_terminated']++;
        }
    }

    /**
     * A branch kiosk that has gone dark.
     *
     * Worth more than an ordinary device-offline notice: the people who depend
     * on a kiosk are the ones with no phone to fall back on, so a tablet that
     * died at six in the morning means a whole shift cannot clock in and nobody
     * finds out until the complaints start.
     *
     * Deliberately silent about a station never seen at all — the row is
     * created at pairing with last_seen_at set, so a null means the pairing
     * went wrong, which is a different problem.
     */
    private function kioskOffline(int $tenantId): void
    {
        $stale = DB::table('attendance_stations as s')
            ->join('branches as b', 'b.id', '=', 's.branch_id')
            ->where('s.tenant_id', $tenantId)
            ->where('s.status', 'active')
            ->whereNotNull('s.last_seen_at')
            ->whereRaw('s.last_seen_at < DATE_SUB(NOW(), INTERVAL ? MINUTE)', [self::KIOSK_SILENCE_MINUTES])
            ->get(['s.id', 's.name', 's.branch_id', 's.last_seen_at', 'b.name as branch_name'])
            ->all();

        foreach ($stale as $row) {
            /** @var array<string, mixed> $station */
            $station = (array) $row;

            $id = Value::int($station['id'] ?? null);
            $branchId = Value::int($station['branch_id'] ?? null);
            $name = Value::string($station['name'] ?? null) ?: 'كيوسك';
            $branch = Value::string($station['branch_name'] ?? null);
            $lastSeen = Value::string($station['last_seen_at'] ?? null);

            $this->fanOut(
                $tenantId, $branchId, 'manage_attendance',
                'kiosk_offline', 'attendance',
                'كيوسك خارج الخدمة',
                "جهاز {$name} في فرع {$branch} لم يتصل منذ {$lastSeen}."
                .' لا يمكن تسجيل الحضور من هذا الجهاز — سجّل الحضور يدويًا حتى يعود.',
                'Kiosk offline',
                "{$name} at {$branch} has not reported since {$lastSeen}."
                .' Attendance cannot be recorded there — record it manually until it returns.',
                ['station_id' => $id, 'branch_id' => $branchId, 'last_seen_at' => $lastSeen],
                // Per station per hour, so a day-long outage does not produce a
                // notification on every run.
                'kioskoffline:'.$id.':'.substr($lastSeen, 0, 13),
                null,
            );

            $this->counts['kiosk_offline']++;
        }
    }

    /**
     * @param  array<string, mixed>  $data
     */
    private function fanOut(
        int $tenantId,
        ?int $branchId,
        string $permission,
        string $prefKey,
        string $type,
        string $titleAr,
        string $bodyAr,
        string $titleEn,
        string $bodyEn,
        array $data,
        string $dedupeKey,
        ?string $countKey,
    ): void {
        foreach (SmartAlert::recipientsForBranch($tenantId, $branchId, $permission) as $adminId) {
            $sent = $this->alerts->dispatch(
                $adminId, $prefKey, $type, $titleAr, $bodyAr, $titleEn, $bodyEn, $data, $dedupeKey,
            );

            if ($sent && $countKey !== null) {
                $this->counts[$countKey]++;
            }
        }
    }
}
