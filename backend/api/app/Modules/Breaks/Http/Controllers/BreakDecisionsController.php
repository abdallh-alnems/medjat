<?php

declare(strict_types=1);

namespace App\Modules\Breaks\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Admin;
use App\Modules\Audit\Domain\AuditLog;
use App\Modules\Breaks\Domain\BreakRequests;
use App\Modules\Breaks\Services\RecordBreakRequest;
use App\Modules\Notifications\Domain\Notifier;
use App\Shared\Http\ApiResponse;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Ports of api/app/breaks/{list,create_for,approve,reject,postpone}.php.
 *
 * The management side of permissions. A decision is only ever made on a request
 * that is still pending and whose window has not closed — approving one after
 * its time has passed would record an absence as authorised retroactively.
 */
final class BreakDecisionsController
{
    public function __construct(
        private readonly BreakRequests $breaks,
        private readonly RecordBreakRequest $record,
        private readonly Notifier $notifier,
    ) {}

    public function index(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));

        // Swept before listing, so a manager is never offered a decision that
        // could only be made retroactively.
        $this->breaks->expirePastPending($tenantId);

        $status = Value::string($request->query('status'));

        return ApiResponse::success([
            'breaks' => $this->breaks->forManager(
                $tenantId,
                Value::int($request->query('branch_id')) ?: null,
                in_array($status, BreakRequests::STATUSES, true) ? $status : null,
                Value::string($request->query('from')) ?: null,
                Value::string($request->query('to')) ?: null,
                Value::int($request->query('category_id')) ?: null,
                trim(Value::string($request->query('search'))) ?: null,
            ),
        ]);
    }

    public function createFor(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;
        $employeeId = Value::int($request->input('employee_id'));

        $exists = $employeeId > 0 && DB::table('employees')
            ->where('id', $employeeId)->where('tenant_id', $tenantId)->exists();

        if (! $exists) {
            throw new ApiFailure(__('messages.employee_not_found'), 404, 'employee_not_found');
        }

        $created = $this->record->execute($request->all(), $employeeId, $tenantId);

        AuditLog::record($tenantId, $adminId, 'break.create', 'break', $created['id']);

        $this->notifier->notifyEmployee(
            $tenantId, $employeeId, 'leave',
            'New Permission', 'إذن جديد',
            'A permission request was created for you.', 'تم إنشاء طلب إذن لك.',
            ['break_id' => (string) $created['id'], 'action' => 'create'],
        );

        return ApiResponse::success(['break_id' => $created['id'], 'message' => 'Break request created']);
    }

    public function approve(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;
        $breakRequest = $this->pending($request, $tenantId);
        $id = Value::int($breakRequest['id'] ?? null);

        $date = Value::string($breakRequest['date'] ?? null);
        $endTime = Value::string($breakRequest['end_time'] ?? null);

        if (BreakRequests::windowHasPassed($tenantId, $date, $endTime)) {
            $this->breaks->expirePastPending($tenantId, Value::int($breakRequest['employee_id'] ?? null));

            throw new ApiFailure(__('messages.permission_window_passed_approve'), 409, 'break_window_passed');
        }

        // The manager's flag wins if they sent one; otherwise the choice made
        // when the request was raised stands.
        $deduct = $request->has('deduct_from_salary')
            ? $request->boolean('deduct_from_salary')
            : Value::int($breakRequest['deduct_from_salary'] ?? null) === 1;

        $this->breaks->approve($id, $tenantId, $adminId, Value::nullableString($request->input('note')), $deduct);

        AuditLog::record($tenantId, $adminId, 'break.approve', 'break', $id);

        $this->tell($tenantId, $breakRequest, $id, 'approve',
            'Break Approved', 'تم قبول الإذن',
            'Your break request has been approved.', 'تمت الموافقة على طلب الإذن الخاص بك.');

        return ApiResponse::success(['message' => 'Break approved']);
    }

    public function reject(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;
        $breakRequest = $this->pending($request, $tenantId);
        $id = Value::int($breakRequest['id'] ?? null);

        $note = trim(Value::string($request->input('rejection_reason') ?? $request->input('note')));

        $this->breaks->reject($id, $tenantId, $adminId, $note !== '' ? $note : null);

        AuditLog::record($tenantId, $adminId, 'break.reject', 'break', $id);

        // The reason travels with the refusal, so the employee does not have to
        // go and ask what they should have done differently.
        $bodyAr = $note !== ''
            ? 'تم رفض طلب الإذن الخاص بك: '.$note
            : 'تم رفض طلب الإذن الخاص بك.';

        $this->tell($tenantId, $breakRequest, $id, 'reject',
            'Break Rejected', 'تم رفض الإذن',
            'Your break request has been rejected.', $bodyAr);

        return ApiResponse::success(['message' => 'Break rejected']);
    }

    /**
     * Offering a different time instead of refusing outright.
     *
     * The employee then accepts or declines it, which is why this leaves the
     * request in its own state rather than approving the new slot on their
     * behalf.
     */
    public function postpone(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;
        $breakRequest = $this->pending($request, $tenantId);
        $id = Value::int($breakRequest['id'] ?? null);

        $date = Value::string($request->input('suggested_date')) ?: null;
        $start = Value::string($request->input('suggested_start_time')) ?: null;
        $end = Value::string($request->input('suggested_end_time')) ?: null;

        if ($date !== null && preg_match('/^\d{4}-\d{2}-\d{2}$/', $date) !== 1) {
            throw new ApiFailure('suggested_date is invalid', 422, 'invalid_date');
        }

        foreach ([$start, $end] as $time) {
            if ($time !== null && preg_match('/^\d{2}:\d{2}(:\d{2})?$/', $time) !== 1) {
                throw new ApiFailure(__('messages.suggested_time_invalid'), 422, 'invalid_time');
            }
        }

        $note = Value::nullableString($request->input('note'));

        $this->breaks->postpone($id, $tenantId, $adminId, $note, $date, $start, $end);

        AuditLog::record($tenantId, $adminId, 'break.postpone', 'break', $id);

        $bodyAr = $date !== null
            ? "تم اقتراح وقت بديل لإذنك: {$date}".($start !== null ? " ({$start}".($end !== null ? " - {$end})" : ')') : '')
            : 'تم تأجيل طلب الإذن الخاص بك.';

        $this->tell($tenantId, $breakRequest, $id, 'postpone',
            'Break Postponed', 'تم تأجيل الإذن',
            'Your break request was postponed.', $bodyAr);

        return ApiResponse::success(['message' => 'Break postponed']);
    }

    /**
     * @param  array<string, mixed>  $breakRequest
     */
    private function tell(
        int $tenantId,
        array $breakRequest,
        int $id,
        string $action,
        string $titleEn,
        string $titleAr,
        string $bodyEn,
        string $bodyAr,
    ): void {
        $this->notifier->notifyEmployee(
            $tenantId,
            Value::int($breakRequest['employee_id'] ?? null),
            'leave',
            $titleEn, $titleAr, $bodyEn, $bodyAr,
            ['break_id' => (string) $id, 'action' => $action],
        );
    }

    /**
     * @return array<string, mixed>
     */
    private function pending(Request $request, int $tenantId): array
    {
        $id = Value::int($request->input('break_id'));
        $breakRequest = $id > 0 ? $this->breaks->find($id, $tenantId) : null;

        if ($breakRequest === null) {
            throw new ApiFailure(__('messages.request_not_found'), 404, 'not_found');
        }

        if (Value::string($breakRequest['status'] ?? null) !== 'pending') {
            throw new ApiFailure(__('messages.request_not_pending'), 409, 'not_pending');
        }

        return $breakRequest;
    }

    private static function admin(Request $request): Admin
    {
        $admin = $request->attributes->get('admin');

        if (! $admin instanceof Admin) {
            throw new ApiFailure(__('messages.authentication_required'), 401);
        }

        return $admin;
    }
}
