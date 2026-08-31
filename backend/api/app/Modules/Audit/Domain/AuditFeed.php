<?php

declare(strict_types=1);

namespace App\Modules\Audit\Domain;

use App\Support\Value;
use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * The company's activity log, as a person reads it.
 *
 * The raw rows say "employee.update on employee 412", which is not an answer to
 * anybody's question. This resolves each row's target into a name, batched one
 * query per target type on the page rather than one per row.
 */
final class AuditFeed
{
    public const PAGE_SIZE = 50;

    /**
     * The high-level categories the client filters by, and the action prefixes
     * each covers.
     *
     * Kept beside the labels the clients render (audit_actions.dart): a
     * category the server does not know becomes a filter that silently returns
     * everything.
     *
     * @var array<string, list<string>>
     */
    public const CATEGORIES = [
        'employees' => [
            'employee.', 'employee_category.', 'document.', 'document_type.',
            'documents.', 'biometric.', 'warning.', 'profile.',
            'onboarding.', 'onboarding_task.', 'onboarding_template.',
        ],
        'attendance' => ['attendance.', 'break.'],
        'schedule' => ['schedule.', 'shift.'],
        'leaves' => ['leave.'],
        'finance' => ['loan.', 'deduction.', 'bonus.', 'payroll.', 'settlement.', 'asset.'],
        'recruitment' => ['candidate.', 'job_opening.'],
        'performance' => [
            'performance_cycle.', 'performance_goal.', 'performance_review.', 'kudos.', 'survey.',
        ],
        'engagement' => ['announcement.', 'analytics.'],
        'settings' => ['tenant.', 'branch.', 'approval_chain.', 'manager.', 'admin.'],
    ];

    /**
     * How a target type resolves to something a person recognises.
     *
     * Targets that hang off a person resolve to that person's name — the
     * question about an assigned asset is "to whom", not "which asset row" —
     * and the rest resolve to their own name.
     *
     * @var array<string, array{table: string, id: string, label: string, join: array{table: string, on: string}|null}>
     */
    private const SUBJECTS = [
        'employee' => ['table' => 'employees', 'id' => 'employees.id', 'label' => 'employees.name', 'join' => null],
        'asset' => ['table' => 'asset_custody', 'id' => 'asset_custody.id', 'label' => 'employees.name',
            'join' => ['table' => 'employees', 'on' => 'asset_custody.employee_id']],
        'loan' => ['table' => 'employee_loans', 'id' => 'employee_loans.id', 'label' => 'employees.name',
            'join' => ['table' => 'employees', 'on' => 'employee_loans.employee_id']],
        'leave' => ['table' => 'leaves', 'id' => 'leaves.id', 'label' => 'employees.name',
            'join' => ['table' => 'employees', 'on' => 'leaves.employee_id']],
        'break' => ['table' => 'break_requests', 'id' => 'break_requests.id', 'label' => 'employees.name',
            'join' => ['table' => 'employees', 'on' => 'break_requests.employee_id']],
        'candidate' => ['table' => 'candidates', 'id' => 'candidates.id', 'label' => 'candidates.name', 'join' => null],
        'shift' => ['table' => 'shifts', 'id' => 'shifts.id', 'label' => 'shifts.name', 'join' => null],
        'branch' => ['table' => 'branches', 'id' => 'branches.id', 'label' => 'branches.name', 'join' => null],
    ];

    /**
     * @param  list<string>|null  $prefixes
     * @return array{items: list<array<string, mixed>>, has_more: bool}
     */
    public static function page(int $tenantId, int $page, ?int $adminId = null, ?array $prefixes = null): array
    {
        $rows = DB::table('audit_log as al')
            ->leftJoin('admins as a', 'a.id', '=', 'al.admin_id')
            ->where('al.tenant_id', $tenantId)
            // System-written rows have no actor and belong to the cron logs, not
            // to a feed of what people did.
            ->whereNotNull('al.admin_id')
            ->when($adminId !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('al.admin_id', $adminId))
            ->when($prefixes !== null && $prefixes !== [], function (QueryBuilder $q) use ($prefixes): void {
                $q->where(function (QueryBuilder $inner) use ($prefixes): void {
                    foreach ($prefixes ?? [] as $prefix) {
                        $inner->orWhere('al.action', 'like', $prefix.'%');
                    }
                });
            })
            ->orderByDesc('al.created_at')
            // One more than the page, so "is there another page" needs no count
            // over a table that only ever grows.
            ->limit(self::PAGE_SIZE + 1)
            ->offset(($page - 1) * self::PAGE_SIZE)
            ->get([
                'al.id', 'al.admin_id', 'al.action', 'al.target_type', 'al.target_id',
                'al.payload', 'al.created_at', 'a.name as admin_name',
            ])
            ->all();

        $hasMore = count($rows) > self::PAGE_SIZE;

        if ($hasMore) {
            array_pop($rows);
        }

        $items = array_values(array_map(
            static function (mixed $row): array {
                /** @var array<string, mixed> $entry */
                $entry = (array) $row;

                return $entry;
            },
            $rows,
        ));

        return ['items' => self::withSubjects($tenantId, $items), 'has_more' => $hasMore];
    }

    /**
     * @param  list<array<string, mixed>>  $rows
     * @return list<array<string, mixed>>
     */
    public static function withSubjects(int $tenantId, array $rows): array
    {
        if ($rows === []) {
            return $rows;
        }

        $wanted = [];

        foreach ($rows as $row) {
            $type = Value::string($row['target_type'] ?? null);
            $id = Value::string($row['target_id'] ?? null);

            // target_id is a varchar and not always numeric — some actions
            // point at a code or a slug, which nothing here can resolve.
            if (isset(self::SUBJECTS[$type]) && ctype_digit($id)) {
                $wanted[$type][(int) $id] = true;
            }
        }

        $labels = [];

        foreach ($wanted as $type => $ids) {
            $labels[$type] = self::labelsFor($type, array_keys($ids), $tenantId);
        }

        foreach ($rows as $index => $row) {
            $type = Value::string($row['target_type'] ?? null);
            $id = Value::string($row['target_id'] ?? null);

            $rows[$index]['subject'] = ctype_digit($id)
                ? ($labels[$type][(int) $id] ?? null)
                : null;
        }

        return $rows;
    }

    /**
     * The distinct actors in this company's log, most recently active first.
     *
     * @return list<array<string, mixed>>
     */
    public static function actors(int $tenantId): array
    {
        $rows = DB::table('audit_log as al')
            ->leftJoin('admins as a', 'a.id', '=', 'al.admin_id')
            ->where('al.tenant_id', $tenantId)
            ->whereNotNull('al.admin_id')
            ->groupBy('al.admin_id', 'a.name')
            ->orderByDesc('last_seen')
            ->get(['al.admin_id as id', 'a.name', DB::raw('MAX(al.created_at) AS last_seen')])
            ->all();

        return array_values(array_map(
            static function (mixed $row): array {
                /** @var array<string, mixed> $actor */
                $actor = (array) $row;

                return $actor;
            },
            $rows,
        ));
    }

    /**
     * @param  list<int>  $ids
     * @return array<int, string>
     */
    private static function labelsFor(string $type, array $ids, int $tenantId): array
    {
        $resolver = self::SUBJECTS[$type];

        try {
            $query = DB::table($resolver['table'])
                ->where($resolver['table'].'.tenant_id', $tenantId)
                ->whereIn($resolver['id'], $ids);

            if ($resolver['join'] !== null) {
                $query->join($resolver['join']['table'], $resolver['join']['table'].'.id', '=', $resolver['join']['on']);
            }

            $rows = $query->get([$resolver['id'].' as id', $resolver['label'].' as label'])->all();
        } catch (Throwable $e) {
            // A missing table must not break the whole feed: it costs the
            // subject line for one kind of row, not the page.
            Log::warning('Audit subject resolve failed', ['type' => $type, 'exception' => $e]);

            return [];
        }

        $labels = [];

        foreach ($rows as $row) {
            /** @var array<string, mixed> $columns */
            $columns = (array) $row;
            $labels[Value::int($columns['id'] ?? null)] = Value::string($columns['label'] ?? null);
        }

        return $labels;
    }
}
