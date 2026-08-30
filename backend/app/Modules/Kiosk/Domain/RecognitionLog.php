<?php

declare(strict_types=1);

namespace App\Modules\Kiosk\Domain;

use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Support\Facades\DB;

/**
 * Every identification attempt a kiosk makes, whatever the outcome.
 *
 * Recorded before the answer is sent, on every path, so "an attempt always
 * leaves a row" is structural rather than remembered. Two things depend on it:
 * a disputed punch can be traced back to the scores behind it, and a company
 * can tune its own threshold from its own data instead of the shipped guess.
 */
final class RecognitionLog
{
    /**
     * @param  array<string, mixed>  $row
     */
    public static function record(array $row, ?int $captureTtlSeconds = null): int
    {
        $columns = [
            'tenant_id' => $row['tenant_id'] ?? null,
            'station_id' => $row['station_id'] ?? null,
            'branch_id' => $row['branch_id'] ?? null,
            'employee_id' => $row['employee_id'] ?? null,
            'purpose' => $row['purpose'] ?? 'check_in',
            'method' => $row['method'] ?? 'face',
            'result' => $row['result'] ?? null,
            'accepted' => empty($row['accepted']) ? 0 : 1,
            'match_score' => $row['match_score'] ?? null,
            'runner_up_score' => $row['runner_up_score'] ?? null,
            'threshold' => $row['threshold'] ?? null,
            'margin' => $row['margin'] ?? null,
            'candidates_searched' => $row['candidates_searched'] ?? null,
            'liveness_passed' => empty($row['liveness_passed']) ? 0 : 1,
            'challenge' => $row['challenge'] ?? null,
            'capture_path' => $row['capture_path'] ?? null,
            'latitude' => $row['latitude'] ?? null,
            'longitude' => $row['longitude'] ?? null,
            'attendance_id' => $row['attendance_id'] ?? null,
        ];

        $logId = (int) DB::table('station_recognition_logs')->insertGetId($columns);

        // Expiry computed in SQL, never in PHP: PHP runs UTC and MySQL runs the
        // server zone, so a PHP-computed timestamp is born hours wrong. Written
        // as a second bound statement rather than interpolated into the insert.
        if ($captureTtlSeconds !== null) {
            DB::update(
                'UPDATE station_recognition_logs SET capture_expires_at = DATE_ADD(NOW(), INTERVAL ? SECOND) WHERE id = ?',
                [$captureTtlSeconds, $logId],
            );
        }

        return $logId;
    }

    public static function linkAttendance(int $logId, int $attendanceId): void
    {
        DB::table('station_recognition_logs')->where('id', $logId)->update(['attendance_id' => $attendanceId]);
    }

    /**
     * Attempts for the management app.
     *
     * The capture path is deliberately not selected. Scores and outcomes are
     * attendance data; the image behind them is biometric evidence and costs a
     * different permission through a different endpoint.
     *
     * @param  array<string, mixed>  $filters
     * @return list<array<string, mixed>>
     */
    public static function search(int $tenantId, array $filters, int $limit = 100): array
    {
        $rows = DB::table('station_recognition_logs as l')
            ->leftJoin('employees as e', 'e.id', '=', 'l.employee_id')
            ->join('attendance_stations as s', 's.id', '=', 'l.station_id')
            ->join('branches as b', 'b.id', '=', 'l.branch_id')
            ->where('l.tenant_id', $tenantId)
            ->when($filters['branch_id'] ?? null, fn (QueryBuilder $q, mixed $v): QueryBuilder => $q->where('l.branch_id', $v))
            ->when($filters['station_id'] ?? null, fn (QueryBuilder $q, mixed $v): QueryBuilder => $q->where('l.station_id', $v))
            ->when($filters['result'] ?? null, fn (QueryBuilder $q, mixed $v): QueryBuilder => $q->where('l.result', $v))
            ->when($filters['date_from'] ?? null, fn (QueryBuilder $q, mixed $v): QueryBuilder => $q->where('l.created_at', '>=', $v))
            ->when($filters['date_to'] ?? null, fn (QueryBuilder $q, mixed $v): QueryBuilder => $q->where('l.created_at', '<=', $v))
            ->orderByDesc('l.created_at')
            ->limit($limit)
            ->get([
                'l.id', 'l.station_id', 'l.branch_id', 'l.employee_id', 'l.purpose', 'l.method',
                'l.result', 'l.accepted', 'l.match_score', 'l.runner_up_score',
                'l.threshold', 'l.margin', 'l.candidates_searched',
                'l.liveness_passed', 'l.attendance_id', 'l.created_at',
                DB::raw('(l.capture_path IS NOT NULL) AS has_capture'),
                'e.name as employee_name', 's.name as station_name', 'b.name as branch_name',
            ])
            ->all();

        return self::rows($rows);
    }

    /**
     * Score histogram in 0.05 buckets, split by outcome.
     *
     * This is how a company sets its own threshold and margin from its own
     * data. Shipping with the defaults and never reading this is how a company
     * ends up with a threshold that rejects half its staff.
     *
     * @return list<array<string, mixed>>
     */
    public static function distribution(int $tenantId, ?int $branchId = null): array
    {
        $rows = DB::table('station_recognition_logs')
            ->where('tenant_id', $tenantId)
            ->whereNotNull('match_score')
            ->when($branchId !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('branch_id', $branchId))
            ->groupBy('bucket', 'result')
            ->orderBy('bucket')
            ->get([
                DB::raw('ROUND(FLOOR(match_score * 20) / 20, 2) AS bucket'),
                'result',
                DB::raw('COUNT(*) AS attempts'),
                DB::raw('AVG(runner_up_score) AS avg_runner_up'),
                DB::raw('AVG(candidates_searched) AS avg_candidates'),
            ])
            ->all();

        return self::rows($rows);
    }

    /**
     * @return list<array<string, mixed>>
     */
    public static function expiredCaptures(int $limit = 500): array
    {
        $rows = DB::table('station_recognition_logs')
            ->whereNotNull('capture_path')
            ->whereNotNull('capture_expires_at')
            ->where('capture_expires_at', '<=', DB::raw('NOW()'))
            ->limit($limit)
            ->get(['id', 'capture_path'])
            ->all();

        return self::rows($rows);
    }

    /** Called only after the file itself has been removed. */
    public static function clearCapture(int $logId): void
    {
        DB::table('station_recognition_logs')->where('id', $logId)->update(['capture_path' => null]);
    }

    /**
     * @param  array<int, mixed>  $rows
     * @return list<array<string, mixed>>
     */
    private static function rows(array $rows): array
    {
        return array_values(array_map(
            static function (mixed $row): array {
                /** @var array<string, mixed> $columns */
                $columns = (array) $row;

                return $columns;
            },
            $rows,
        ));
    }
}
