<?php

declare(strict_types=1);

namespace App\Modules\Documents\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Admin;
use App\Models\Employee;
use App\Modules\Audit\Domain\AuditLog;
use App\Modules\Documents\Domain\DocumentChecklist;
use App\Modules\Documents\Domain\DocumentUpload;
use App\Modules\Notifications\Domain\ManagerAlert;
use App\Shared\Http\ApiResponse;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\UploadedFile;

/**
 * Ports upload_document.php (an administrator filing on somebody's behalf) and
 * submit_document.php (the employee handing one in themselves).
 */
final class UploadDocumentController
{
    public function __construct(private readonly ManagerAlert $managers) {}

    public function byAdmin(Request $request): JsonResponse
    {
        $admin = $request->attributes->get('admin');
        if (! $admin instanceof Admin) {
            throw new ApiFailure(__('messages.authentication_required'), 401);
        }

        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $employeeId = Value::int($request->input('employee_id'));
        $typeId = Value::int($request->input('document_type_id'));

        if ($employeeId <= 0 || $typeId <= 0) {
            throw new ApiFailure('employee_id and document_type_id are required', 422, 'missing_fields');
        }

        if (! Employee::query()->forTenant($tenantId)->whereKey($employeeId)->exists()) {
            throw new ApiFailure(__('messages.employee_not_found'), 404);
        }

        $documentId = DocumentUpload::store($this->file($request), $tenantId, $employeeId, $typeId, $admin->id);

        AuditLog::record($tenantId, $admin->id, 'document.upload', 'employee', $employeeId);

        return ApiResponse::success(['document_id' => $documentId]);
    }

    public function byEmployee(Request $request): JsonResponse
    {
        $employee = $request->attributes->get('employee');
        if (! $employee instanceof Employee) {
            throw new ApiFailure(__('messages.authentication_required'), 401);
        }

        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $typeId = Value::int($request->input('document_type_id'));

        if ($typeId <= 0) {
            throw new ApiFailure('document_type_id is required', 422, 'missing_fields');
        }

        // The requirement has to actually apply to this person. Without the
        // check an employee could file against any requirement in the company,
        // including one scoped to somebody else entirely.
        $required = $this->applicableRequirement($employee->id, $tenantId, $typeId);
        if ($required === null) {
            throw new ApiFailure(__('messages.document_not_required_for_you'), 403, 'document_not_required');
        }

        $documentId = DocumentUpload::store($this->file($request), $tenantId, $employee->id, $typeId, null);

        $employeeName = trim(Value::string($employee->name)) ?: 'موظف';
        $documentName = Value::string($required['document_type_name'] ?? null, 'مستند');

        $this->managers->notify(
            tenantId: $tenantId,
            type: 'approval',
            titleAr: 'مستند بانتظار المراجعة',
            titleEn: 'Document awaiting review',
            bodyAr: "{$employeeName} أرسل مستند \"{$documentName}\" للمراجعة.",
            bodyEn: "{$employeeName} submitted the document \"{$documentName}\" for review.",
            aboutEmployeeId: $employee->id,
            data: [
                'action' => 'document_submitted',
                'employee_document_id' => (string) $documentId,
                // The management app opens the submissions screen for one
                // document *type*, so the uploaded row id alone is not enough
                // to open it.
                'required_document_id' => (string) $typeId,
                'document_name' => $documentName,
            ],
        );

        return ApiResponse::success(['document_id' => $documentId, 'status' => 'uploaded']);
    }

    /**
     * @return array<string, mixed>|null
     */
    private function applicableRequirement(int $employeeId, int $tenantId, int $typeId): ?array
    {
        foreach (DocumentChecklist::forEmployee($employeeId, $tenantId) as $item) {
            if (Value::int($item['required_document_id'] ?? null) === $typeId) {
                return $item;
            }
        }

        return null;
    }

    private function file(Request $request): UploadedFile
    {
        $file = $request->file('file');

        if (! $file instanceof UploadedFile || ! $file->isValid()) {
            throw new ApiFailure(__('messages.no_file_uploaded'), 400, 'no_file');
        }

        return $file;
    }
}
