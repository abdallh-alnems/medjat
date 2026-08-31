<?php

declare(strict_types=1);

namespace App\Modules\Payroll\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Admin;
use App\Modules\Audit\Domain\AuditLog;
use App\Modules\Payroll\Domain\PayrollCache;
use App\Shared\Http\ApiResponse;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Ports of api/app/deductions/{get_rules,save_config}.php.
 *
 * The ladder a company charges lateness by, and what an absence costs.
 */
final class DeductionRulesController
{
    /**
     * What the calculator falls back to when a company has configured nothing.
     *
     * The default shown here must match what payroll actually applies, or
     * opening the screen and pressing save would silently change everybody's
     * deductions.
     */
    private const DEFAULT_ABSENCE_MULTIPLIER = 1.5;

    public function show(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));

        $rules = DB::table('deduction_rules')
            ->where('tenant_id', $tenantId)->where('is_active', 1)
            ->get()
            ->map(static function (object $row): array {
                /** @var array<string, mixed> $columns */
                $columns = (array) $row;

                return $columns;
            })->all();

        $byKey = [];
        foreach ($rules as $rule) {
            $byKey[Value::string($rule['rule_key'] ?? null)] = $rule['rule_value'] ?? null;
        }

        $tiers = DB::table('late_deduction_tiers')
            ->where('tenant_id', $tenantId)
            ->orderBy('threshold_minutes')
            ->get(['id', 'threshold_minutes', 'deduction_days'])
            ->map(static fn (object $row): array => [
                'id' => Value::int($row->id),
                'threshold_minutes' => Value::int($row->threshold_minutes),
                'deduction_days' => Value::float($row->deduction_days),
            ])->all();

        return ApiResponse::success([
            'rules' => $rules,
            'config' => [
                'late_type' => Value::string($byKey['late_type'] ?? null, 'tiered'),
                'absence_days' => isset($byKey['absence_multiplier'])
                    ? Value::float($byKey['absence_multiplier'])
                    : self::DEFAULT_ABSENCE_MULTIPLIER,
                'tiers' => $tiers,
            ],
        ]);
    }

    public function save(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;

        $absenceDays = Value::float($request->input('absence_days'));

        if ($absenceDays < 0) {
            throw new ApiFailure('يجب أن يكون خصم الغياب صفراً أو أكثر', 422, 'invalid_absence_days');
        }

        $tiers = $this->tiers($request);

        DB::transaction(function () use ($tenantId, $tiers, $absenceDays): void {
            $this->upsertRule($tenantId, 'late_type', 'text', 'tiered', 'نوع خصم التأخير');
            $this->upsertRule(
                $tenantId, 'absence_multiplier', 'numeric',
                (string) $absenceDays, 'خصم الغياب (أيام لكل يوم غياب)',
            );

            // The ladder is replaced wholesale: it is a statement of what a
            // company charges now, and merging would leave rungs nobody chose.
            DB::table('late_deduction_tiers')->where('tenant_id', $tenantId)->delete();

            if ($tiers !== []) {
                DB::table('late_deduction_tiers')->insert(array_map(
                    static fn (array $tier): array => $tier + ['tenant_id' => $tenantId],
                    $tiers,
                ));
            }
        });

        AuditLog::record($tenantId, $adminId, 'deduction.rules_updated', 'tenant', $tenantId, [
            'tiers' => count($tiers),
            'absence_days' => $absenceDays,
        ]);

        PayrollCache::invalidate($tenantId);

        return ApiResponse::success(['message' => 'تم حفظ قواعد الخصم']);
    }

    /**
     * @return list<array{threshold_minutes: int, deduction_days: float}>
     */
    private function tiers(Request $request): array
    {
        $raw = $request->input('tiers', []);

        if (! is_array($raw)) {
            throw new ApiFailure('صيغة الشرائح غير صحيحة', 422, 'invalid_tiers');
        }

        $tiers = [];
        $seen = [];

        foreach ($raw as $tier) {
            if (! is_array($tier)) {
                continue;
            }

            $minutes = Value::int($tier['threshold_minutes'] ?? $tier['minutes'] ?? null);
            $days = Value::float($tier['deduction_days'] ?? $tier['days'] ?? null);

            if ($minutes <= 0) {
                throw new ApiFailure('عتبة الدقائق يجب أن تكون أكبر من صفر', 422, 'invalid_threshold');
            }

            if ($days <= 0) {
                throw new ApiFailure('قيمة الخصم يجب أن تكون أكبر من صفر', 422, 'invalid_deduction_days');
            }

            // A repeated threshold makes the ladder ambiguous: two rungs at the
            // same height, and no way to say which one applies.
            if (isset($seen[$minutes])) {
                throw new ApiFailure("عتبة الدقائق {$minutes} مكررة", 422, 'duplicate_threshold');
            }

            $seen[$minutes] = true;
            $tiers[] = ['threshold_minutes' => $minutes, 'deduction_days' => $days];
        }

        return $tiers;
    }

    private function upsertRule(int $tenantId, string $key, string $type, string $value, string $description): void
    {
        DB::table('deduction_rules')->upsert(
            [[
                'tenant_id' => $tenantId,
                'rule_key' => $key,
                'rule_type' => $type,
                'rule_value' => $value,
                'description' => $description,
                'is_active' => 1,
            ]],
            ['tenant_id', 'rule_key'],
            ['rule_type', 'rule_value', 'description'],
        );
    }

    private static function admin(Request $request): Admin
    {
        $admin = $request->attributes->get('admin');

        if (! $admin instanceof Admin) {
            throw new ApiFailure('Authentication required', 401);
        }

        return $admin;
    }
}
