<?php

declare(strict_types=1);

namespace App\Modules\Documents\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Employee;
use App\Modules\Documents\Domain\DocumentChecklist;
use App\Shared\Http\ApiResponse;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Ports get_documents.php and get_missing_documents.php.
 */
final class EmployeeDocumentsController
{
    public function index(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $employeeId = $this->employeeId($request, $tenantId);

        $documents = DB::table('employee_documents as ed')
            ->leftJoin('required_documents as rd', 'rd.id', '=', 'ed.required_document_id')
            ->where('ed.employee_id', $employeeId)
            ->where('ed.tenant_id', $tenantId)
            ->orderByDesc('ed.created_at')
            ->get([
                'ed.id', 'ed.required_document_id', 'ed.original_name', 'ed.status',
                'ed.expires_at', 'ed.notes', 'ed.rejected_reason', 'ed.verified_at',
                'ed.created_at', 'rd.name as document_name', 'rd.category',
            ]);

        return ApiResponse::success([
            'documents' => array_values(array_map(static fn (object $r): array => (array) $r, $documents->all())),
            'required_documents' => DocumentChecklist::forEmployee($employeeId, $tenantId),
        ]);
    }

    /**
     * What is still outstanding: nothing uploaded, rejected, or expired.
     *
     * A rejected document counts as missing — the requirement is unmet whether
     * nothing arrived or the wrong thing did — and so does an expired one.
     */
    public function missing(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $employeeId = $this->employeeId($request, $tenantId);

        $missing = array_values(array_filter(
            DocumentChecklist::forEmployee($employeeId, $tenantId),
            static fn (array $item): bool => in_array($item['status'] ?? null, ['required', 'rejected', 'expired'], true),
        ));

        return ApiResponse::success(['missing_documents' => $missing]);
    }

    private function employeeId(Request $request, int $tenantId): int
    {
        $employeeId = Value::int($request->query('employee_id'));

        if ($employeeId <= 0) {
            throw new ApiFailure('employee_id is required', 422, 'missing_fields');
        }

        $exists = Employee::query()->forTenant($tenantId)->whereKey($employeeId)->exists();
        if (! $exists) {
            throw new ApiFailure(__('messages.employee_not_found'), 404);
        }

        return $employeeId;
    }
}
