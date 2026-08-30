<?php

declare(strict_types=1);

namespace App\Modules\Payroll\Http\Controllers;

use App\Modules\Payroll\Domain\PayrollCache;
use App\Modules\Payroll\Domain\PayrollLedger;
use App\Modules\Payroll\Services\LiveOverview;
use App\Shared\Http\ApiResponse;
use App\Shared\Time\TenantClock;
use App\Support\Value;
use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Port of api/app/payroll/live.php.
 *
 * The payroll screen's main view. Cached for ninety seconds, but only for the
 * current month: a past cycle cannot change, so caching it would trade freshness
 * for nothing.
 */
final class LiveController
{
    public function __construct(
        private readonly LiveOverview $overview,
        private readonly PayrollLedger $ledger,
    ) {}

    public function __invoke(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $today = TenantClock::date($tenantId);
        $currentMonth = substr($today, 0, 7);

        $month = Value::string($request->query('month'), '') ?: $currentMonth;
        $branchId = self::optionalId($request->query('branch_id'));
        $limit = $request->query('limit') === null ? null : max(1, min(500, Value::int($request->query('limit'))));
        $offset = max(0, Value::int($request->query('offset')));

        $cacheKey = $month === $currentMonth
            ? PayrollCache::key($tenantId, $month, $branchId, $limit, $offset)
            : null;

        if ($cacheKey !== null) {
            $cached = PayrollCache::get($cacheKey);

            if ($cached !== null) {
                return ApiResponse::success($cached)->header('X-Cache', 'HIT');
            }
        }

        $result = $this->overview->forMonth($tenantId, $month, $branchId, $limit, $offset);

        $payload = $result + [
            'limit' => $limit,
            'offset' => $offset,
        ] + $this->tenantContext($tenantId)
          + ['min_hire_date' => $this->earliestHireDate($tenantId, $branchId)];

        $previous = $this->previousSummary($tenantId, $month, $branchId);
        if ($previous !== null) {
            $payload['previous_summary'] = $previous;
        }

        if ($cacheKey === null) {
            return ApiResponse::success($payload);
        }

        PayrollCache::put($cacheKey, $payload);

        return ApiResponse::success($payload)->header('X-Cache', 'MISS');
    }

    /**
     * The cycle start day and currency, so the client can label the picker and
     * put the right symbol next to every figure.
     *
     * @return array<string, mixed>
     */
    private function tenantContext(int $tenantId): array
    {
        $tenant = DB::table('tenants')->where('id', $tenantId)->first(['cycle_start_day', 'currency']);

        return [
            'cycle_start_day' => $tenant === null ? 1 : Value::int($tenant->cycle_start_day, 1),
            'currency' => $tenant === null ? 'EGP' : Value::string($tenant->currency, 'EGP'),
        ];
    }

    /**
     * How far back the month picker may go. Scoped to the branch filter so the
     * picker matches the rows on screen rather than the whole company.
     */
    private function earliestHireDate(int $tenantId, ?int $branchId): ?string
    {
        return Value::nullableString(
            DB::table('employees')
                ->where('tenant_id', $tenantId)
                ->where('status', 'active')
                ->whereNotNull('hire_date')
                ->when($branchId !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('branch_id', $branchId))
                ->min('hire_date')
        );
    }

    /**
     * @return array<string, mixed>|null
     */
    private function previousSummary(int $tenantId, string $month, ?int $branchId): ?array
    {
        $previousMonth = LiveOverview::previousMonth($month);
        $summary = $this->ledger->summary($tenantId, $previousMonth, $branchId);

        // Nothing was generated for that month, so there is no comparison to
        // draw and the client hides the delta rather than showing a fall to zero.
        if (Value::int($summary['employee_count'] ?? null) <= 0) {
            return null;
        }

        return [
            'month' => $previousMonth,
            'employee_count' => Value::int($summary['employee_count'] ?? null),
            'total_net' => Value::float($summary['total_net'] ?? null),
            'total_deductions' => Value::float($summary['total_deductions'] ?? null),
            'total_bonuses' => Value::float($summary['total_bonuses'] ?? null),
        ];
    }

    private static function optionalId(mixed $raw): ?int
    {
        $id = Value::int($raw);

        return $id > 0 ? $id : null;
    }
}
