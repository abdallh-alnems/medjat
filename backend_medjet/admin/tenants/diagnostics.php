<?php
// "The check-in keeps failing" — this endpoint answers that call.
//
// Everything a support agent needs to explain a rejected attendance attempt,
// gathered per company for a recent window: how the face matcher is scoring,
// what the anti-spoofing layer blocked, whether the branch WiFi is actually
// approved, whether the terminals and kiosks are still phoning home, and which
// channels people are really using.
//
// The window is 30 days by default. Everything is aggregate plus a short tail
// of recent rows — enough to diagnose, small enough to render on a phone.
//
// Kiosk tables live on an unmerged feature branch, so their section degrades to
// null on a database where the migration has not been applied yet rather than
// 500-ing mid-call.
require_once __DIR__ . '/../../config/bootstrap.php';

class TenantDiagnosticsApi extends AdminBaseApi {
    protected ?string $minRole = 'readonly';

    public function __construct() {
        parent::__construct();
        $this->handleRequest(function () {
            $id = (int) $this->getField('id');
            if ($id <= 0) {
                $this->error('معرّف الشركة مطلوب', 422);
            }

            $tenant = Database::fetchOne(
                "SELECT id, name, face_match_threshold, face_enforce_mode, face_liveness_required,
                        reject_mock_location, last_absence_date
                 FROM tenants WHERE id = ? LIMIT 1",
                [$id]
            );
            if (!$tenant) {
                $this->notFound('Tenant');
            }

            $days = (int) ($this->getField('days') ?? 30);
            $days = max(1, min(90, $days));

            $this->success([
                'window_days' => $days,
                'face' => $this->face($id, $days, $tenant),
                'security' => $this->security($id, $days),
                'wifi' => $this->wifi($id),
                'devices' => $this->devices($id),
                'kiosks' => $this->kiosks($id),
                'channels' => $this->channels($id, $days),
                'cron' => [
                    'last_absence_date' => $tenant['last_absence_date'],
                    'today' => TenantClock::date($id),
                ],
            ]);
        }, 'admin.tenants.diagnostics');
    }

    /**
     * Face matching. The number that matters is the rejection rate against the
     * company's own threshold: a company sitting at 0.65 with half its genuine
     * attempts scoring below it is mis-tuned, not being defrauded.
     */
    private function face(int $tenantId, int $days, array $tenant): array {
        $summary = Database::fetchOne(
            "SELECT COUNT(*) AS attempts,
                    SUM(accepted = 1) AS accepted,
                    SUM(result = 'below_threshold') AS below_threshold,
                    SUM(result = 'liveness_failed') AS liveness_failed,
                    SUM(result = 'not_enrolled') AS not_enrolled,
                    SUM(result = 'invalid_challenge') AS invalid_challenge,
                    AVG(match_score) AS avg_score,
                    MIN(match_score) AS min_score,
                    MAX(match_score) AS max_score
             FROM face_verification_logs
             WHERE tenant_id = ? AND created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)",
            [$tenantId, $days]
        );

        $recent = Database::fetchAll(
            "SELECT l.id, l.employee_id, e.name AS employee_name, l.result, l.accepted,
                    l.match_score, l.threshold, l.liveness_passed, l.purpose, l.created_at
             FROM face_verification_logs l
             LEFT JOIN employees e ON e.id = l.employee_id
             WHERE l.tenant_id = ? AND l.accepted = 0
             ORDER BY l.id DESC
             LIMIT 10",
            [$tenantId]
        );

        $attempts = (int) ($summary['attempts'] ?? 0);

        return [
            'enforce_mode' => $tenant['face_enforce_mode'],
            'threshold' => (float) $tenant['face_match_threshold'],
            'liveness_required' => (int) $tenant['face_liveness_required'],
            'attempts' => $attempts,
            'accepted' => (int) ($summary['accepted'] ?? 0),
            'rejection_rate' => $attempts > 0
                ? round(1 - ((int) $summary['accepted'] / $attempts), 3)
                : null,
            'below_threshold' => (int) ($summary['below_threshold'] ?? 0),
            'liveness_failed' => (int) ($summary['liveness_failed'] ?? 0),
            'not_enrolled' => (int) ($summary['not_enrolled'] ?? 0),
            'invalid_challenge' => (int) ($summary['invalid_challenge'] ?? 0),
            'avg_score' => $summary['avg_score'] !== null ? round((float) $summary['avg_score'], 3) : null,
            'min_score' => $summary['min_score'] !== null ? round((float) $summary['min_score'], 3) : null,
            'max_score' => $summary['max_score'] !== null ? round((float) $summary['max_score'], 3) : null,
            'recent_rejections' => array_map(static function (array $r): array {
                return [
                    'employee_id' => (int) $r['employee_id'],
                    'employee_name' => $r['employee_name'],
                    'result' => $r['result'],
                    'match_score' => $r['match_score'] !== null ? (float) $r['match_score'] : null,
                    'threshold' => $r['threshold'] !== null ? (float) $r['threshold'] : null,
                    'liveness_passed' => (int) $r['liveness_passed'],
                    'purpose' => $r['purpose'],
                    'created_at' => $r['created_at'],
                ];
            }, $recent),
        ];
    }

    /** Anti-spoofing: what was blocked or merely flagged, and why. */
    private function security(int $tenantId, int $days): array {
        $byReason = Database::fetchAll(
            "SELECT reason, action, COUNT(*) AS c
             FROM attendance_security_logs
             WHERE tenant_id = ? AND created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
             GROUP BY reason, action
             ORDER BY c DESC",
            [$tenantId, $days]
        );

        $recent = Database::fetchAll(
            "SELECT s.id, s.employee_id, e.name AS employee_name, s.reason, s.action,
                    s.platform, s.app_version, s.created_at
             FROM attendance_security_logs s
             LEFT JOIN employees e ON e.id = s.employee_id
             WHERE s.tenant_id = ?
             ORDER BY s.id DESC
             LIMIT 10",
            [$tenantId]
        );

        return [
            'by_reason' => array_map(static function (array $r): array {
                return [
                    'reason' => $r['reason'],
                    'action' => $r['action'],
                    'count' => (int) $r['c'],
                ];
            }, $byReason),
            'recent' => array_map(static function (array $r): array {
                return [
                    'employee_id' => (int) $r['employee_id'],
                    'employee_name' => $r['employee_name'],
                    'reason' => $r['reason'],
                    'action' => $r['action'],
                    'platform' => $r['platform'],
                    'app_version' => $r['app_version'],
                    'created_at' => $r['created_at'],
                ];
            }, $recent),
        ];
    }

    /**
     * WiFi coverage per branch. One router usually broadcasts several BSSIDs
     * (2.4 and 5 GHz), so a branch with discovered-but-unapproved networks is
     * the classic "half my staff can't check in" call.
     */
    private function wifi(int $tenantId): array {
        $rows = Database::fetchAll(
            "SELECT b.id AS branch_id, b.name AS branch_name,
                    COUNT(n.id) AS total,
                    SUM(n.is_active = 1) AS active,
                    SUM(n.source = 'discovered' AND n.is_active = 0) AS pending_approval
             FROM branches b
             LEFT JOIN branch_networks n ON n.branch_id = b.id AND n.tenant_id = b.tenant_id
             WHERE b.tenant_id = ?
             GROUP BY b.id, b.name
             ORDER BY b.name",
            [$tenantId]
        );

        return array_map(static function (array $r): array {
            return [
                'branch_id' => (int) $r['branch_id'],
                'branch_name' => $r['branch_name'],
                'networks' => (int) $r['total'],
                'approved' => (int) $r['active'],
                'pending_approval' => (int) $r['pending_approval'],
            ];
        }, $rows);
    }

    /** ZKTeco terminals: is it still dialling home, and when did it last punch? */
    private function devices(int $tenantId): array {
        $rows = Database::fetchAll(
            "SELECT d.id, d.serial_number, d.name, d.vendor, d.model, d.status,
                    d.last_seen_at, d.last_punch_at, d.last_ip, d.user_count,
                    b.name AS branch_name
             FROM attendance_devices d
             LEFT JOIN branches b ON b.id = d.branch_id
             WHERE d.tenant_id = ?
             ORDER BY d.last_seen_at IS NULL, d.last_seen_at DESC",
            [$tenantId]
        );

        return array_map(static function (array $r): array {
            return [
                'id' => (int) $r['id'],
                'serial_number' => $r['serial_number'],
                'name' => $r['name'],
                'vendor' => $r['vendor'],
                'model' => $r['model'],
                'status' => $r['status'],
                'branch_name' => $r['branch_name'],
                'last_seen_at' => $r['last_seen_at'],
                'last_punch_at' => $r['last_punch_at'],
                'last_ip' => $r['last_ip'],
                'user_count' => $r['user_count'] !== null ? (int) $r['user_count'] : null,
            ];
        }, $rows);
    }

    /** Branch kiosks. Null when the feature's migration has not been applied. */
    private function kiosks(int $tenantId): ?array {
        if (!$this->tableExists('attendance_stations')) {
            return null;
        }

        $rows = Database::fetchAll(
            "SELECT s.id, s.name, s.status, s.app_version, s.last_seen_at, s.last_punch_at,
                    s.punch_count, b.name AS branch_name
             FROM attendance_stations s
             LEFT JOIN branches b ON b.id = s.branch_id
             WHERE s.tenant_id = ?
             ORDER BY s.last_seen_at IS NULL, s.last_seen_at DESC",
            [$tenantId]
        );

        return array_map(static function (array $r): array {
            return [
                'id' => (int) $r['id'],
                'name' => $r['name'],
                'status' => $r['status'],
                'branch_name' => $r['branch_name'],
                'app_version' => $r['app_version'],
                'last_seen_at' => $r['last_seen_at'],
                'last_punch_at' => $r['last_punch_at'],
                'punch_count' => (int) $r['punch_count'],
            ];
        }, $rows);
    }

    /** Which channels people actually check in through. */
    private function channels(int $tenantId, int $days): array {
        $rows = Database::fetchAll(
            "SELECT check_in_method AS method, COUNT(*) AS c
             FROM attendance
             WHERE tenant_id = ? AND check_in_time IS NOT NULL
               AND date >= DATE_SUB(CURDATE(), INTERVAL ? DAY)
             GROUP BY check_in_method
             ORDER BY c DESC",
            [$tenantId, $days]
        );

        return array_map(static function (array $r): array {
            return ['method' => $r['method'], 'count' => (int) $r['c']];
        }, $rows);
    }

    private function tableExists(string $table): bool {
        static $cache = [];
        if (!array_key_exists($table, $cache)) {
            $row = Database::fetchOne(
                "SELECT COUNT(*) AS c FROM information_schema.tables
                 WHERE table_schema = DATABASE() AND table_name = ?",
                [$table]
            );
            $cache[$table] = ((int) ($row['c'] ?? 0)) > 0;
        }
        return $cache[$table];
    }
}

new TenantDiagnosticsApi();
