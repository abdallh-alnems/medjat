<?php

declare(strict_types=1);

namespace App\Modules\Documents\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Admin;
use App\Modules\Audit\Domain\AuditLog;
use App\Modules\Notifications\Domain\Notifier;
use App\Shared\Http\ApiResponse;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Ports verify_document.php, reject_document.php, update_document.php and
 * delete_document.php.
 *
 * Approving or refusing somebody's paperwork is the kind of decision they have
 * to hear about, so each one notifies them — and a rejection carries the reason,
 * because "rejected" on its own tells them nothing they can act on.
 */
final class ReviewDocumentController
{
    public function __construct(private readonly Notifier $notifier) {}

    public function verify(Request $request): JsonResponse
    {
        [$admin, $tenantId, $document] = $this->context($request, Value::int($request->input('document_id')));

        // 'uploaded' with a verified_at, not a 'verified' status: the column's
        // enum has no such value, and approval is recorded by *who and when*
        // rather than by a state that would say nothing about either.
        DB::table('employee_documents')->where('id', $document->id)->update([
            'status' => 'uploaded',
            'verified_at' => DB::raw('NOW()'),
            'verified_by' => $admin->id,
            'rejected_reason' => null,
        ]);

        AuditLog::record($tenantId, $admin->id, 'document.verify', 'employee_document', Value::int($document->id));

        $name = $this->documentName($document);
        $this->notifier->notifyEmployee(
            tenantId: $tenantId,
            employeeId: Value::int($document->employee_id),
            type: 'approval',
            titleEn: 'Document Approved',
            titleAr: 'تم قبول مستندك',
            bodyEn: "Your document \"{$name}\" has been approved.",
            bodyAr: "تمت الموافقة على مستند \"{$name}\".",
            data: ['employee_document_id' => (string) $document->id, 'action' => 'approve', 'type' => 'document_approved'],
        );

        return ApiResponse::success(['document_id' => Value::int($document->id)]);
    }

    public function reject(Request $request): JsonResponse
    {
        [$admin, $tenantId, $document] = $this->context($request, Value::int($request->input('document_id')));

        $reason = trim(Value::string($request->input('reason')));
        if ($reason === '') {
            throw new ApiFailure('reason is required', 422, 'missing_fields');
        }

        DB::table('employee_documents')->where('id', $document->id)->update([
            'status' => 'rejected',
            'rejected_reason' => $reason,
            'verified_at' => null,
            'verified_by' => null,
        ]);

        AuditLog::record($tenantId, $admin->id, 'document.reject', 'employee_document', Value::int($document->id), [
            'reason' => $reason,
        ]);

        $name = $this->documentName($document);
        $this->notifier->notifyEmployee(
            tenantId: $tenantId,
            employeeId: Value::int($document->employee_id),
            type: 'approval',
            titleEn: 'Document Rejected',
            titleAr: 'تم رفض مستندك',
            // The reason travels with it: "rejected" on its own tells the
            // employee nothing they can act on, and they will simply upload the
            // same file again.
            bodyEn: "Your document \"{$name}\" was rejected. Reason: {$reason}",
            bodyAr: "تم رفض مستند \"{$name}\". السبب: {$reason}",
            data: ['employee_document_id' => (string) $document->id, 'action' => 'reject', 'type' => 'document_rejected'],
        );

        return ApiResponse::success(['document_id' => Value::int($document->id)]);
    }

    public function update(Request $request, int $id): JsonResponse
    {
        [$admin, $tenantId, $document] = $this->context($request, $id);

        $changes = [];

        if ($request->has('notes')) {
            $changes['notes'] = Value::nullableString($request->input('notes'));
        }

        if ($request->has('expires_at')) {
            $expiresAt = Value::string($request->input('expires_at'));

            if ($expiresAt !== '' && preg_match('/^\d{4}-\d{2}-\d{2}$/', $expiresAt) !== 1) {
                throw new ApiFailure('Invalid expires_at date. Use Y-m-d', 400, 'invalid_date');
            }

            $changes['expires_at'] = $expiresAt === '' ? null : $expiresAt;
        }

        if ($changes !== []) {
            DB::table('employee_documents')->where('id', $document->id)->update($changes);
        }

        AuditLog::record($tenantId, $admin->id, 'document.update', 'employee_document', Value::int($document->id));

        return ApiResponse::success(['document_id' => Value::int($document->id)]);
    }

    public function destroy(Request $request, int $id): JsonResponse
    {
        [$admin, $tenantId, $document] = $this->context($request, $id);

        DB::table('employee_documents')->where('id', $document->id)->delete();

        AuditLog::record($tenantId, $admin->id, 'document.delete', 'employee_document', Value::int($document->id));

        return ApiResponse::success(['message' => 'Document deleted']);
    }

    /**
     * @return array{Admin, int, object{id: int, employee_id: int, original_name: string|null, document_name: string|null}}
     */
    private function context(Request $request, int $documentId): array
    {
        $admin = $request->attributes->get('admin');
        if (! $admin instanceof Admin) {
            throw new ApiFailure('Authentication required', 401);
        }

        $tenantId = Value::int($request->attributes->get('tenant_id'));

        if ($documentId <= 0) {
            throw new ApiFailure('document_id is required', 422, 'missing_fields');
        }

        /** @var object{id: int, employee_id: int, original_name: string|null, document_name: string|null}|null $document */
        $document = DB::table('employee_documents as ed')
            ->leftJoin('required_documents as rd', 'rd.id', '=', 'ed.required_document_id')
            ->where('ed.id', $documentId)
            ->where('ed.tenant_id', $tenantId)
            ->first(['ed.id', 'ed.employee_id', 'ed.original_name', 'rd.name as document_name']);

        if ($document === null) {
            throw new ApiFailure('Document not found', 404);
        }

        return [$admin, $tenantId, $document];
    }

    /**
     * @param  object{original_name: string|null, document_name: string|null}  $document
     */
    private function documentName(object $document): string
    {
        $name = Value::string($document->document_name);

        if ($name !== '') {
            return $name;
        }

        return Value::string($document->original_name, 'المستند');
    }
}
