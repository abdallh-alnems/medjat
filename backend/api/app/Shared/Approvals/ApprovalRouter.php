<?php

declare(strict_types=1);

namespace App\Shared\Approvals;

use App\Support\Value;
use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Support\Facades\DB;

/**
 * Multi-step approval, when a company has configured one.
 *
 * Most companies have not, and that is the important case: with no matching
 * chain nothing is routed and the request simply waits for whoever has the
 * permission. Routing is an addition to that, never a precondition — a company
 * that has never opened the approvals screen must not find its leave requests
 * stuck behind an empty chain.
 */
final class ApprovalRouter
{
    public const ENTITY_TYPES = ['leave', 'loan', 'bonus', 'warning', 'document', 'generic'];

    /**
     * @return int|null The request id, or null when nothing was routed.
     */
    public function route(
        int $tenantId,
        string $entityType,
        int $entityId,
        ?float $amount = null,
        ?int $branchId = null,
        ?int $byAdminId = null,
        ?int $byEmployeeId = null,
    ): ?int {
        if (! in_array($entityType, self::ENTITY_TYPES, true)) {
            return null;
        }

        $chain = $this->resolveChain($tenantId, $entityType, $amount, $branchId);

        if ($chain === null) {
            return null;
        }

        return DB::transaction(function () use ($tenantId, $chain, $entityType, $entityId, $amount, $byAdminId, $byEmployeeId): int {
            $steps = $chain['steps'];

            $requestId = (int) DB::table('approval_requests')->insertGetId([
                'tenant_id' => $tenantId,
                'chain_id' => Value::int($chain['id'] ?? null),
                'entity_type' => $entityType,
                'entity_id' => $entityId,
                'requested_by_admin_id' => $byAdminId,
                'requested_by_employee_id' => $byEmployeeId,
                'context_amount' => $amount,
                'current_step' => 1,
                'total_steps' => count($steps),
                'status' => 'pending',
            ]);

            $order = 1;
            foreach ($steps as $step) {
                DB::table('approval_request_steps')->insert([
                    'tenant_id' => $tenantId,
                    'request_id' => $requestId,
                    'step_order' => $order,
                    'approver_type' => $step['approver_type'] ?? null,
                    'approver_role' => $step['approver_role'] ?? null,
                    'approver_admin_id' => $step['approver_admin_id'] ?? null,
                    'label' => $step['label'] ?? null,
                    'status' => 'pending',
                ]);
                $order++;
            }

            return $requestId;
        });
    }

    public function isPending(int $tenantId, string $entityType, int $entityId): bool
    {
        return DB::table('approval_requests')
            ->where('tenant_id', $tenantId)
            ->where('entity_type', $entityType)
            ->where('entity_id', $entityId)
            ->where('status', 'pending')
            ->exists();
    }

    /**
     * Close any open chain for this entity.
     *
     * Called when somebody with the permission decides directly from the
     * management screen: that decision stands, and leaving the chain open would
     * park the request in an approver's inbox forever.
     */
    public function cancelFor(int $tenantId, string $entityType, int $entityId): void
    {
        DB::table('approval_requests')
            ->where('tenant_id', $tenantId)
            ->where('entity_type', $entityType)
            ->where('entity_id', $entityId)
            ->where('status', 'pending')
            ->update(['status' => 'cancelled', 'decided_at' => DB::raw('NOW()')]);
    }

    /**
     * The most specific active chain that has any steps.
     *
     * A chain with no steps is skipped rather than used: it would open a
     * request nobody can ever act on.
     *
     * @return array{id: int, steps: list<array<string, mixed>>}|null
     */
    private function resolveChain(int $tenantId, string $entityType, ?float $amount, ?int $branchId): ?array
    {
        $candidates = DB::table('approval_chains as c')
            ->where('c.tenant_id', $tenantId)
            ->where('c.request_type', $entityType)
            ->where('c.is_active', 1)
            ->when(
                $amount !== null,
                fn (QueryBuilder $q): QueryBuilder => $q->where(fn (QueryBuilder $sub): QueryBuilder => $sub
                    ->whereNull('c.min_amount')->orWhere('c.min_amount', '<=', $amount)),
                fn (QueryBuilder $q): QueryBuilder => $q->whereNull('c.min_amount'),
            )
            ->when(
                $branchId !== null,
                fn (QueryBuilder $q): QueryBuilder => $q->where(fn (QueryBuilder $sub): QueryBuilder => $sub
                    ->whereNull('c.branch_id')->orWhere('c.branch_id', $branchId)),
                fn (QueryBuilder $q): QueryBuilder => $q->whereNull('c.branch_id'),
            )
            ->orderByDesc('c.priority')->orderByDesc('c.id')
            ->pluck('c.id');

        foreach ($candidates as $id) {
            $chainId = Value::int($id);
            $steps = $this->steps($tenantId, $chainId);

            if ($steps !== []) {
                return ['id' => $chainId, 'steps' => $steps];
            }
        }

        return null;
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function steps(int $tenantId, int $chainId): array
    {
        $rows = DB::table('approval_chain_steps')
            ->where('chain_id', $chainId)->where('tenant_id', $tenantId)
            ->orderBy('step_order')
            ->get(['approver_type', 'approver_role', 'approver_admin_id', 'label'])
            ->all();

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
