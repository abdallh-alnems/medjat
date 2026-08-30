<?php

declare(strict_types=1);

namespace App\Http\Controllers\Documents;

use App\Domain\Audit\AuditLog;
use App\Domain\Documents\DocumentChecklist;
use App\Exceptions\ApiFailure;
use App\Http\ApiResponse;
use App\Models\Admin;
use App\Models\Employee;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Port of api/app/employees/request_document.php.
 *
 * Asking one person for a document. Two ways in: an ad-hoc requirement typed by
 * hand, or an existing entry from the company's catalogue.
 */
final class RequestDocumentController
{
    /** @var list<string> */
    private const CATEGORIES = ['identity', 'contract', 'certificate', 'insurance', 'general'];

    public function __invoke(Request $request): JsonResponse
    {
        $admin = $request->attributes->get('admin');
        if (! $admin instanceof Admin) {
            throw new ApiFailure('Authentication required', 401);
        }

        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $employeeId = Value::int($request->input('employee_id'));

        if ($employeeId <= 0) {
            throw new ApiFailure('employee_id is required', 422, 'missing_fields');
        }

        if (! Employee::query()->forTenant($tenantId)->whereKey($employeeId)->exists()) {
            throw new ApiFailure('Employee not found', 404);
        }

        $typeId = Value::int($request->input('required_document_id'));
        $customName = trim(Value::string($request->input('name')));

        return $typeId <= 0 && $customName !== ''
            ? $this->custom($request, $admin, $tenantId, $employeeId, $customName)
            : $this->fromCatalogue($admin, $tenantId, $employeeId, $typeId);
    }

    /**
     * An ad-hoc requirement, specific to this person and not part of the
     * company's catalogue.
     */
    private function custom(Request $request, Admin $admin, int $tenantId, int $employeeId, string $name): JsonResponse
    {
        $category = Value::nullableString($request->input('category'));
        if ($category !== null && $category !== '' && ! in_array($category, self::CATEGORIES, true)) {
            throw new ApiFailure('Invalid category', 422, 'invalid_category');
        }

        $description = trim(Value::string($request->input('description')));
        $expiryDays = Value::nullableInt($request->input('expiry_days'));

        $requiredId = (int) DB::table('required_documents')->insertGetId([
            'tenant_id' => $tenantId,
            'name' => mb_substr($name, 0, 100),
            'description' => $description === '' ? null : $description,
            'category' => $category === '' ? null : $category,
            'expiry_days' => $expiryDays === 0 ? null : $expiryDays,
            'scope_type' => 'employees',
            'scope_branch_id' => null,
            'is_required' => $request->boolean('is_required', true) ? 1 : 0,
            'is_active' => 1,
        ]);

        DB::table('required_document_employees')->insert([
            'required_document_id' => $requiredId,
            'employee_id' => $employeeId,
            'tenant_id' => $tenantId,
        ]);

        AuditLog::record($tenantId, $admin->id, 'document.request', 'employee', $employeeId, [
            'required_document_id' => $requiredId,
            'custom' => true,
        ]);

        return ApiResponse::success([
            'required_document_id' => $requiredId,
            'already_requested' => false,
            'custom' => true,
        ]);
    }

    private function fromCatalogue(Admin $admin, int $tenantId, int $employeeId, int $typeId): JsonResponse
    {
        if ($typeId <= 0) {
            throw new ApiFailure('required_document_id is required', 422, 'missing_fields');
        }

        $type = DB::table('required_documents')
            ->where('id', $typeId)->where('tenant_id', $tenantId)->first();

        if ($type === null) {
            throw new ApiFailure('Document type not found', 404);
        }

        // Idempotent: if the type already reaches this employee through any
        // scope, there is nothing to request. Saying so beats silently creating
        // a second copy of a requirement they already have.
        foreach (DocumentChecklist::forEmployee($employeeId, $tenantId) as $item) {
            if (Value::int($item['required_document_id'] ?? null) === $typeId) {
                return ApiResponse::success([
                    'required_document_id' => $typeId,
                    'already_requested' => true,
                ]);
            }
        }

        if (Value::string($type->scope_type, 'all') === 'employees') {
            // Already an employee-scoped entry: just add this person to its list.
            DB::table('required_document_employees')->insertOrIgnore([
                'required_document_id' => $typeId,
                'employee_id' => $employeeId,
                'tenant_id' => $tenantId,
            ]);

            $resultId = $typeId;
        } else {
            // A broad type that does not currently cover this employee. A copy
            // scoped to them is created rather than the shared rule being
            // widened — asking one person for something must not quietly put it
            // on everybody's checklist.
            $resultId = (int) DB::table('required_documents')->insertGetId([
                'tenant_id' => $tenantId,
                'name' => $type->name,
                'description' => $type->description,
                'category' => Value::string($type->category, 'general'),
                'expiry_days' => $type->expiry_days,
                'notification_days_before' => Value::int($type->notification_days_before, 30),
                'is_required' => Value::int($type->is_required, 1) === 1 ? 1 : 0,
                'scope_type' => 'employees',
                'scope_branch_id' => null,
                'is_active' => 1,
            ]);

            DB::table('required_document_employees')->insert([
                'required_document_id' => $resultId,
                'employee_id' => $employeeId,
                'tenant_id' => $tenantId,
            ]);
        }

        AuditLog::record($tenantId, $admin->id, 'document.request', 'employee', $employeeId, [
            'required_document_id' => $resultId,
            'source_type_id' => $typeId,
        ]);

        return ApiResponse::success([
            'required_document_id' => $resultId,
            'already_requested' => false,
        ]);
    }
}
