<?php

declare(strict_types=1);

namespace App\Modules\Leave\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Admin;
use App\Modules\Audit\Domain\AuditLog;
use App\Modules\Leave\Services\YearRollover;
use App\Shared\Http\ApiResponse;
use App\Support\Value;
use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Ports of api/app/leaves/{carryover_policies_list,carryover_policy_save,
 * carryover_policy_delete,rollover,encashments_list}.php.
 *
 * Carryover rules and the yearly run that applies them.
 */
final class CarryoverController
{
    public function __construct(private readonly YearRollover $rollover) {}

    public function index(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));

        $policies = DB::table('leave_carryover_policies')
            ->where('tenant_id', $tenantId)
            // Broadest scope first, so the list reads the way the rules are
            // inherited rather than in insertion order.
            ->orderByRaw("FIELD(scope_type, 'tenant', 'branch', 'category', 'employee')")
            ->orderBy('scope_id')->orderBy('min_seniority_months')
            ->get([
                'id', 'scope_type', 'scope_id', 'min_seniority_months', 'carryover_enabled',
                'carryover_max_days', 'expiry_months', 'encash_excess', 'legal_min_carry_days',
                'created_at', 'updated_at',
            ])
            ->all();

        return ApiResponse::success(['policies' => self::rows($policies)]);
    }

    public function save(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;

        $scopeType = Value::string($request->input('scope_type'));

        // The company-wide policy is edited from the leave settings screen; two
        // ways to write the same row is how the two screens end up disagreeing.
        if (! in_array($scopeType, ['branch', 'category', 'employee'], true)) {
            throw new ApiFailure(
                'scope_type must be branch, category or employee',
                422,
                'scope_type_branch_category_employee',
            );
        }

        $scopeId = Value::int($request->input('scope_id'));

        if ($scopeId <= 0) {
            throw new ApiFailure('scope_id is required', 422, 'scope_id_required');
        }

        DB::table('leave_carryover_policies')->upsert(
            [[
                'tenant_id' => $tenantId,
                'scope_type' => $scopeType,
                'scope_id' => $scopeId,
                'min_seniority_months' => max(0, Value::int($request->input('min_seniority_months'))),
                'carryover_enabled' => $request->boolean('carryover_enabled') ? 1 : 0,
                'carryover_max_days' => self::bounded($request, 'carryover_max_days', 366, 'carryover_max_days_between_0'),
                'expiry_months' => self::bounded($request, 'expiry_months', 60, 'expiry_months_between_0_60'),
                'encash_excess' => $request->boolean('encash_excess') ? 1 : 0,
                'legal_min_carry_days' => self::bounded($request, 'legal_min_carry_days', 366, 'legal_min_carry_days_between'),
            ]],
            ['tenant_id', 'scope_type', 'scope_id', 'min_seniority_months'],
            ['carryover_enabled', 'carryover_max_days', 'expiry_months', 'encash_excess', 'legal_min_carry_days'],
        );

        // The submitted fields, not the whole request: the trail should record
        // the policy that was set, not whatever else the client sent along.
        AuditLog::record($tenantId, $adminId, 'leave.carryover_policy.save', $scopeType, $scopeId, [
            'min_seniority_months' => max(0, Value::int($request->input('min_seniority_months'))),
            'carryover_enabled' => $request->boolean('carryover_enabled'),
            'carryover_max_days' => $request->input('carryover_max_days'),
            'expiry_months' => $request->input('expiry_months'),
            'encash_excess' => $request->boolean('encash_excess'),
            'legal_min_carry_days' => $request->input('legal_min_carry_days'),
        ]);

        return ApiResponse::success(['message' => 'Carryover policy saved']);
    }

    public function delete(Request $request, int $id): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;

        if ($id <= 0) {
            throw new ApiFailure('id is required', 422, 'id_required');
        }

        // Deleting an override restores inheritance from the parent scope
        // rather than turning carryover off.
        DB::table('leave_carryover_policies')->where('id', $id)->where('tenant_id', $tenantId)->delete();

        AuditLog::record($tenantId, $adminId, 'leave.carryover_policy.delete', 'leave_carryover_policy', $id);

        return ApiResponse::success(['message' => 'Carryover policy removed']);
    }

    public function rollover(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;
        $fromYear = Value::int($request->input('from_year'));

        if ($fromYear < 2000 || $fromYear > 2100) {
            throw new ApiFailure('from_year must be a valid year', 422, 'from_year_valid_year');
        }

        $result = $this->rollover->run($tenantId, $fromYear);

        AuditLog::record($tenantId, $adminId, 'leave.rollover', 'tenant', $tenantId, $result);

        return ApiResponse::success(['message' => 'Leave balances rolled over'] + $result);
    }

    public function encashments(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $status = Value::string($request->query('status')) ?: null;
        $limit = min(1000, max(1, Value::int($request->query('limit'), 200)));

        $rows = DB::table('leave_encashments as le')
            ->join('employees as e', 'e.id', '=', 'le.employee_id')
            ->where('le.tenant_id', $tenantId)
            ->when($status !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('le.status', $status))
            ->orderByDesc('le.created_at')
            ->limit($limit)
            ->get([
                'le.id', 'le.employee_id', 'e.name as employee_name', 'le.source_year',
                'le.days', 'le.daily_rate', 'le.amount', 'le.status', 'le.payroll_month', 'le.created_at',
            ])
            ->all();

        return ApiResponse::success(['encashments' => self::rows($rows)]);
    }

    /**
     * An optional whole number inside a range; absent stays absent, because a
     * blank field means "inherit", not "zero".
     */
    private static function bounded(Request $request, string $field, int $max, string $errorCode): ?int
    {
        $raw = $request->input($field);

        if ($raw === null || $raw === '') {
            return null;
        }

        $value = Value::int($raw);

        if ($value < 0 || $value > $max) {
            throw new ApiFailure("{$field} must be between 0 and {$max}", 422, $errorCode);
        }

        return $value;
    }

    private static function admin(Request $request): Admin
    {
        $admin = $request->attributes->get('admin');

        if (! $admin instanceof Admin) {
            throw new ApiFailure(__('messages.authentication_required'), 401);
        }

        return $admin;
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
