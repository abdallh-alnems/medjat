<?php

declare(strict_types=1);

namespace App\Modules\Kiosk\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Attendance;
use App\Models\Employee;
use App\Modules\Kiosk\Domain\KioskStation;
use App\Modules\Kiosk\Domain\RecognitionLog;
use App\Shared\Http\ApiResponse;
use App\Shared\Time\TenantClock;
use App\Support\Value;
use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Port of api/app/kiosk/punch.php.
 *
 * Redeems a ticket issued by identification and writes the attendance. The
 * employee is named by the ticket, never by the request, so a tablet cannot
 * identify as one person and punch as another.
 */
final class PunchController
{
    public function __invoke(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $branchId = Value::int($request->attributes->get('branch_id'));
        $stationId = Value::int($request->attributes->get('station_id'));

        $ticket = Value::string($request->input('punch_ticket'));
        $idempotencyKey = Value::string($request->input('idempotency_key'));

        if ($ticket === '' || $idempotencyKey === '') {
            throw new ApiFailure('punch_ticket and idempotency_key are required', 422, 'missing_fields');
        }

        // Checked before the ticket is redeemed. A retry after a lost response
        // arrives with the same key and a ticket that was already spent;
        // treating that as an error would tell the employee their punch failed
        // when it succeeded.
        //
        // Each direction carries its own key: one attendance row holds both a
        // check-in and a check-out, so a single column would let the second
        // punch overwrite the first one's key and void its replay protection.
        $replayed = DB::table('attendance')
            ->where('tenant_id', $tenantId)
            ->where(function (QueryBuilder $either) use ($idempotencyKey): void {
                $either->where('kiosk_checkin_idem_key', $idempotencyKey)
                    ->orWhere('kiosk_checkout_idem_key', $idempotencyKey);
            })
            ->first(['id', 'check_in_time', 'check_out_time', 'worked_minutes']);

        if ($replayed !== null) {
            return ApiResponse::success([
                'attendance_id' => Value::int($replayed->id),
                'replayed' => true,
                'recorded_at' => $replayed->check_out_time ?: $replayed->check_in_time,
                'worked_minutes' => Value::nullableInt($replayed->worked_minutes),
            ]);
        }

        $employeeId = $this->redeemTicket($ticket, $tenantId);
        $employee = Employee::query()->where('id', $employeeId)->where('tenant_id', $tenantId)->first();

        if ($employee === null) {
            throw new ApiFailure('Employee not found', 404, 'not_found');
        }

        // The ticket is thirty seconds old, but a transfer in that window must
        // not land a punch on the wrong branch's books.
        if (Value::int($employee->branch_id) !== $branchId) {
            throw new ApiFailure(__('messages.kiosk_out_of_branch'), 403, 'kiosk_out_of_branch');
        }

        $direction = Value::string($request->input('direction'), 'check_in') === 'check_out'
            ? 'check_out'
            : 'check_in';

        [$recognitionMethod, $confidence, $logId] = $this->provenance(
            Value::int($request->input('recognition_log_id')), $tenantId, $stationId, $employeeId
        );

        $attendanceId = $direction === 'check_in'
            ? Attendance::recordCheckIn($employeeId, $branchId, $tenantId, 'kiosk', null, null, false, $recognitionMethod, $confidence)
            : $this->closeDay($employeeId, $tenantId);

        // Close the loop: the recognition attempt now points at the punch it
        // produced, so a disputed row can be traced back to the scores behind it.
        if ($logId !== null && $attendanceId > 0) {
            RecognitionLog::linkAttendance($logId, $attendanceId);
        }

        DB::table('attendance')->where('id', $attendanceId)->where('tenant_id', $tenantId)->update([
            'station_id' => $stationId,
            $direction === 'check_in' ? 'kiosk_checkin_idem_key' : 'kiosk_checkout_idem_key' => $idempotencyKey,
        ]);

        KioskStation::recordPunch($stationId);

        $final = DB::table('attendance')->where('id', $attendanceId)
            ->first(['check_in_time', 'check_out_time', 'worked_minutes', 'late_minutes']);

        return ApiResponse::success([
            'attendance_id' => $attendanceId,
            'direction' => $direction,
            'replayed' => false,
            'recorded_at' => $direction === 'check_in'
                ? ($final->check_in_time ?? null)
                : ($final->check_out_time ?? null),
            'employee' => ['id' => $employeeId, 'name' => $employee->name],
            'worked_minutes' => Value::nullableInt($final?->worked_minutes),
            'late_minutes' => Value::nullableInt($final?->late_minutes),
        ]);
    }

    /**
     * Single-use and short-lived, claimed in SQL so two taps cannot both spend
     * it.
     */
    private function redeemTicket(string $ticket, int $tenantId): int
    {
        $claimed = DB::update(
            'UPDATE face_challenges SET consumed_at = NOW()'
            .' WHERE nonce = ? AND tenant_id = ? AND consumed_at IS NULL AND expires_at > NOW()',
            [$ticket, $tenantId],
        );

        if ($claimed === 0) {
            throw new ApiFailure(__('messages.kiosk_no_match'), 410, 'kiosk_ticket_spent');
        }

        $employeeId = Value::int(DB::table('face_challenges')->where('nonce', $ticket)->value('employee_id'));

        if ($employeeId <= 0) {
            throw new ApiFailure(__('messages.kiosk_no_match'), 410, 'kiosk_ticket_spent');
        }

        return $employeeId;
    }

    /**
     * How this person was identified, read off the recognition log rather than
     * taken from the request.
     *
     * The client supplies the row id, but every field that ends up on the
     * attendance record comes from what the server wrote at identification
     * time. A tablet cannot upgrade a code punch into a face punch by asserting
     * it, which matters because face-versus-code is the security boundary of
     * the feature.
     *
     * With no verifiable row, the punch is still recorded but claims no
     * recognition method: a null is honest, and a face claim would be evidence
     * that does not exist.
     *
     * @return array{0: string|null, 1: float|null, 2: int|null}
     */
    private function provenance(int $logId, int $tenantId, int $stationId, int $employeeId): array
    {
        if ($logId <= 0) {
            return [null, null, null];
        }

        $row = DB::table('station_recognition_logs')
            ->where('id', $logId)
            ->where('tenant_id', $tenantId)
            ->where('station_id', $stationId)
            ->where('employee_id', $employeeId)
            ->where('accepted', 1)
            ->where('created_at', '>', DB::raw('DATE_SUB(NOW(), INTERVAL 5 MINUTE)'))
            ->first(['id', 'method', 'match_score']);

        if ($row === null) {
            return [null, null, null];
        }

        return [
            Value::string($row->method) === 'code' ? 'station_code' : 'station_face',
            is_numeric($row->match_score) ? (float) $row->match_score : null,
            Value::int($row->id),
        ];
    }

    private function closeDay(int $employeeId, int $tenantId): int
    {
        Attendance::recordCheckOut($employeeId, $tenantId);

        $id = Value::int(
            DB::table('attendance')
                ->where('employee_id', $employeeId)
                ->where('date', TenantClock::date($tenantId))
                ->where('tenant_id', $tenantId)
                ->value('id')
        );

        DB::table('attendance')->where('id', $id)->update(['check_out_method' => 'kiosk']);

        return $id;
    }
}
