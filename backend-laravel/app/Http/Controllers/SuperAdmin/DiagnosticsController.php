<?php

declare(strict_types=1);

namespace App\Http\Controllers\SuperAdmin;

use App\Domain\Time\TenantClock;
use App\Exceptions\ApiFailure;
use App\Http\ApiResponse;
use App\Support\Value;
use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Database\Query\JoinClause;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Port of api/admin/tenants/diagnostics.php.
 *
 * "The check-in keeps failing" — this answers that call.
 *
 * Everything a support agent needs to explain a rejected attempt, per company
 * over a recent window: how the face matcher is scoring, what anti-spoofing
 * blocked, whether the branch WiFi is actually approved, whether the terminals
 * and kiosks are still phoning home, and which channels people really use.
 *
 * Aggregates plus a short tail of recent rows — enough to diagnose, small
 * enough to render on a phone.
 */
final class DiagnosticsController
{
    private const DEFAULT_WINDOW_DAYS = 30;

    private const MAX_WINDOW_DAYS = 90;

    private const RECENT_LIMIT = 10;

    public function __invoke(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->query('id')) ?: Value::int($request->input('id'));

        if ($tenantId <= 0) {
            throw new ApiFailure('معرّف الشركة مطلوب', 422, 'id_required');
        }

        $row = DB::table('tenants')->where('id', $tenantId)->first([
            'id', 'name', 'face_match_threshold', 'face_enforce_mode', 'face_liveness_required',
            'reject_mock_location', 'last_absence_date',
        ]);

        if ($row === null) {
            throw new ApiFailure('Tenant not found', 404, 'not_found');
        }

        /** @var array<string, mixed> $tenant */
        $tenant = (array) $row;

        $days = min(self::MAX_WINDOW_DAYS, max(1, Value::int($request->query('days'), self::DEFAULT_WINDOW_DAYS)));

        return ApiResponse::success([
            'window_days' => $days,
            'face' => $this->face($tenantId, $days, $tenant),
            'security' => $this->security($tenantId, $days),
            'wifi' => $this->wifi($tenantId),
            'devices' => $this->devices($tenantId),
            'kiosks' => $this->kiosks($tenantId),
            'channels' => $this->channels($tenantId, $days),
            'cron' => [
                'last_absence_date' => $tenant['last_absence_date'] ?? null,
                // The company's own date, which is the one the absence run used.
                'today' => TenantClock::date($tenantId),
            ],
        ]);
    }

    /**
     * Face matching.
     *
     * The number that matters is the rejection rate against the company's own
     * threshold: a company sitting at 0.65 with half its genuine attempts
     * scoring below it is mis-tuned, not being defrauded.
     *
     * @param  array<string, mixed>  $tenant
     * @return array<string, mixed>
     */
    private function face(int $tenantId, int $days, array $tenant): array
    {
        $summary = self::row(
            DB::table('face_verification_logs')
                ->where('tenant_id', $tenantId)
                ->whereRaw('created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)', [$days])
                ->selectRaw(
                    'COUNT(*) AS attempts,'
                    .' COALESCE(SUM(accepted = 1), 0) AS accepted,'
                    ." COALESCE(SUM(result = 'below_threshold'), 0) AS below_threshold,"
                    ." COALESCE(SUM(result = 'liveness_failed'), 0) AS liveness_failed,"
                    ." COALESCE(SUM(result = 'not_enrolled'), 0) AS not_enrolled,"
                    ." COALESCE(SUM(result = 'invalid_challenge'), 0) AS invalid_challenge,"
                    .' AVG(match_score) AS avg_score,'
                    .' MIN(match_score) AS min_score,'
                    .' MAX(match_score) AS max_score'
                )
        );

        $attempts = Value::int($summary['attempts'] ?? null);
        $accepted = Value::int($summary['accepted'] ?? null);

        $recent = DB::table('face_verification_logs as l')
            ->leftJoin('employees as e', 'e.id', '=', 'l.employee_id')
            ->where('l.tenant_id', $tenantId)->where('l.accepted', 0)
            ->orderByDesc('l.id')->limit(self::RECENT_LIMIT)
            ->get([
                'l.employee_id', 'e.name as employee_name', 'l.result', 'l.match_score',
                'l.threshold', 'l.liveness_passed', 'l.purpose', 'l.created_at',
            ])
            ->all();

        return [
            'enforce_mode' => $tenant['face_enforce_mode'] ?? null,
            'threshold' => Value::float($tenant['face_match_threshold'] ?? null),
            'liveness_required' => Value::int($tenant['face_liveness_required'] ?? null),
            'attempts' => $attempts,
            'accepted' => $accepted,
            'rejection_rate' => $attempts > 0 ? round(1 - $accepted / $attempts, 3) : null,
            'below_threshold' => Value::int($summary['below_threshold'] ?? null),
            'liveness_failed' => Value::int($summary['liveness_failed'] ?? null),
            'not_enrolled' => Value::int($summary['not_enrolled'] ?? null),
            'invalid_challenge' => Value::int($summary['invalid_challenge'] ?? null),
            'avg_score' => self::rounded($summary['avg_score'] ?? null),
            'min_score' => self::rounded($summary['min_score'] ?? null),
            'max_score' => self::rounded($summary['max_score'] ?? null),
            'recent_rejections' => self::map($recent, static fn (array $r): array => [
                'employee_id' => Value::int($r['employee_id'] ?? null),
                'employee_name' => $r['employee_name'] ?? null,
                'result' => $r['result'] ?? null,
                'match_score' => Value::nullableFloat($r['match_score'] ?? null),
                'threshold' => Value::nullableFloat($r['threshold'] ?? null),
                'liveness_passed' => Value::int($r['liveness_passed'] ?? null),
                'purpose' => $r['purpose'] ?? null,
                'created_at' => $r['created_at'] ?? null,
            ]),
        ];
    }

    /**
     * Anti-spoofing: what was blocked or merely flagged, and why.
     *
     * @return array<string, mixed>
     */
    private function security(int $tenantId, int $days): array
    {
        $byReason = DB::table('attendance_security_logs')
            ->where('tenant_id', $tenantId)
            ->whereRaw('created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)', [$days])
            ->groupBy('reason', 'action')
            ->orderByDesc('c')
            ->get(['reason', 'action', DB::raw('COUNT(*) AS c')])
            ->all();

        $recent = DB::table('attendance_security_logs as s')
            ->leftJoin('employees as e', 'e.id', '=', 's.employee_id')
            ->where('s.tenant_id', $tenantId)
            ->orderByDesc('s.id')->limit(self::RECENT_LIMIT)
            ->get([
                's.employee_id', 'e.name as employee_name', 's.reason', 's.action',
                's.platform', 's.app_version', 's.created_at',
            ])
            ->all();

        return [
            'by_reason' => self::map($byReason, static fn (array $r): array => [
                'reason' => $r['reason'] ?? null,
                'action' => $r['action'] ?? null,
                'count' => Value::int($r['c'] ?? null),
            ]),
            'recent' => self::map($recent, static fn (array $r): array => [
                'employee_id' => Value::int($r['employee_id'] ?? null),
                'employee_name' => $r['employee_name'] ?? null,
                'reason' => $r['reason'] ?? null,
                'action' => $r['action'] ?? null,
                'platform' => $r['platform'] ?? null,
                'app_version' => $r['app_version'] ?? null,
                'created_at' => $r['created_at'] ?? null,
            ]),
        ];
    }

    /**
     * WiFi coverage per branch.
     *
     * One router usually broadcasts several BSSIDs (2.4 and 5 GHz), so a branch
     * with discovered-but-unapproved networks is the classic "half my staff
     * can't check in" call.
     *
     * @return list<array<string, mixed>>
     */
    private function wifi(int $tenantId): array
    {
        $rows = DB::table('branches as b')
            ->leftJoin('branch_networks as n', function (JoinClause $join): void {
                $join->on('n.branch_id', '=', 'b.id')->on('n.tenant_id', '=', 'b.tenant_id');
            })
            ->where('b.tenant_id', $tenantId)
            ->groupBy('b.id', 'b.name')
            ->orderBy('b.name')
            ->get([
                'b.id as branch_id', 'b.name as branch_name',
                DB::raw('COUNT(n.id) AS total'),
                DB::raw('COALESCE(SUM(n.is_active = 1), 0) AS active'),
                DB::raw("COALESCE(SUM(n.source = 'discovered' AND n.is_active = 0), 0) AS pending_approval"),
            ])
            ->all();

        return self::map($rows, static fn (array $r): array => [
            'branch_id' => Value::int($r['branch_id'] ?? null),
            'branch_name' => $r['branch_name'] ?? null,
            'networks' => Value::int($r['total'] ?? null),
            'approved' => Value::int($r['active'] ?? null),
            'pending_approval' => Value::int($r['pending_approval'] ?? null),
        ]);
    }

    /**
     * ZKTeco terminals: is it still dialling home, and when did it last punch?
     *
     * @return list<array<string, mixed>>
     */
    private function devices(int $tenantId): array
    {
        $rows = DB::table('attendance_devices as d')
            ->leftJoin('branches as b', 'b.id', '=', 'd.branch_id')
            ->where('d.tenant_id', $tenantId)
            ->orderByRaw('d.last_seen_at IS NULL')
            ->orderByDesc('d.last_seen_at')
            ->get([
                'd.id', 'd.serial_number', 'd.name', 'd.vendor', 'd.model', 'd.status',
                'd.last_seen_at', 'd.last_punch_at', 'd.last_ip', 'd.user_count', 'b.name as branch_name',
            ])
            ->all();

        return self::map($rows, static fn (array $r): array => [
            'id' => Value::int($r['id'] ?? null),
            'serial_number' => $r['serial_number'] ?? null,
            'name' => $r['name'] ?? null,
            'vendor' => $r['vendor'] ?? null,
            'model' => $r['model'] ?? null,
            'status' => $r['status'] ?? null,
            'branch_name' => $r['branch_name'] ?? null,
            'last_seen_at' => $r['last_seen_at'] ?? null,
            'last_punch_at' => $r['last_punch_at'] ?? null,
            'last_ip' => $r['last_ip'] ?? null,
            'user_count' => Value::nullableInt($r['user_count'] ?? null),
        ]);
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function kiosks(int $tenantId): array
    {
        $rows = DB::table('attendance_stations as s')
            ->leftJoin('branches as b', 'b.id', '=', 's.branch_id')
            ->where('s.tenant_id', $tenantId)
            ->orderByRaw('s.last_seen_at IS NULL')
            ->orderByDesc('s.last_seen_at')
            ->get([
                's.id', 's.name', 's.status', 's.app_version', 's.last_seen_at',
                's.last_punch_at', 's.punch_count', 'b.name as branch_name',
            ])
            ->all();

        return self::map($rows, static fn (array $r): array => [
            'id' => Value::int($r['id'] ?? null),
            'name' => $r['name'] ?? null,
            'status' => $r['status'] ?? null,
            'branch_name' => $r['branch_name'] ?? null,
            'app_version' => $r['app_version'] ?? null,
            'last_seen_at' => $r['last_seen_at'] ?? null,
            'last_punch_at' => $r['last_punch_at'] ?? null,
            'punch_count' => Value::int($r['punch_count'] ?? null),
        ]);
    }

    /**
     * Which channels people actually check in through.
     *
     * @return list<array<string, mixed>>
     */
    private function channels(int $tenantId, int $days): array
    {
        $rows = DB::table('attendance')
            ->where('tenant_id', $tenantId)
            ->whereNotNull('check_in_time')
            ->whereRaw('date >= DATE_SUB(CURDATE(), INTERVAL ? DAY)', [$days])
            ->groupBy('check_in_method')
            ->orderByDesc('c')
            ->get(['check_in_method as method', DB::raw('COUNT(*) AS c')])
            ->all();

        return self::map($rows, static fn (array $r): array => [
            'method' => $r['method'] ?? null,
            'count' => Value::int($r['c'] ?? null),
        ]);
    }

    private static function rounded(mixed $value): ?float
    {
        $number = Value::nullableFloat($value);

        return $number === null ? null : round($number, 3);
    }

    /**
     * @param  array<int, mixed>  $rows
     * @param  callable(array<string, mixed>): array<string, mixed>  $shape
     * @return list<array<string, mixed>>
     */
    private static function map(array $rows, callable $shape): array
    {
        return array_values(array_map(static function (mixed $row) use ($shape): array {
            /** @var array<string, mixed> $columns */
            $columns = (array) $row;

            return $shape($columns);
        }, $rows));
    }

    /**
     * @return array<string, mixed>
     */
    private static function row(QueryBuilder $query): array
    {
        /** @var array<string, mixed> $row */
        $row = (array) $query->first();

        return $row;
    }
}
