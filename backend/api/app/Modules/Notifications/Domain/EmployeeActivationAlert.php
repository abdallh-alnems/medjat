<?php

declare(strict_types=1);

namespace App\Modules\Notifications\Domain;

use App\Models\Employee;
use App\Support\Value;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * Tells a company's managers that one of their staff signed in.
 *
 * Fires on every sign-in, and says which kind it was: the first one is the
 * account being linked, which is the event HR is actually waiting for after
 * handing somebody an activation code.
 *
 * Never throws — an employee's sign-in must not fail because their manager
 * could not be told about it.
 */
final class EmployeeActivationAlert
{
    public function __construct(private readonly PushSender $push) {}

    public function notify(Employee $employee, bool $isFirstActivation): void
    {
        try {
            $tenantId = $employee->tenant_id;
            $name = trim(Value::string($employee->name)) ?: 'موظف';

            $branchName = $employee->branch_id === null ? '' : Value::string(
                DB::table('branches')->where('id', $employee->branch_id)->value('name')
            );
            $suffix = $branchName === '' ? '' : " ({$branchName})";

            [$titleAr, $title, $bodyAr, $body, $event] = $isFirstActivation
                ? [
                    'تفعيل حساب موظف',
                    'Employee account activated',
                    "{$name} قام بتفعيل حسابه وتسجيل الدخول إلى التطبيق.{$suffix}",
                    "{$name} activated their account and signed in to the app.{$suffix}",
                    'employee_activated',
                ]
                : [
                    'تسجيل دخول موظف',
                    'Employee signed in',
                    "{$name} سجّل الدخول إلى التطبيق.{$suffix}",
                    "{$name} signed in to the app.{$suffix}",
                    'employee_login',
                ];

            $data = [
                'type' => $event,
                'employee_id' => (string) $employee->id,
                'branch_id' => $employee->branch_id === null ? '' : (string) $employee->branch_id,
            ];

            $managers = DB::table('admins')
                ->where('tenant_id', $tenantId)
                ->whereNotIn('role', ['employee', 'pending'])
                ->pluck('id');

            foreach ($managers as $id) {
                $adminId = Value::int($id);

                // Persisted as well as pushed, so it is in the manager's list
                // even when the push is not delivered.
                DB::table('notifications')->insert([
                    'tenant_id' => $tenantId,
                    'admin_id' => $adminId,
                    'employee_id' => $employee->id,
                    'type' => 'system',
                    'title' => $title,
                    'title_ar' => $titleAr,
                    'body' => $body,
                    'body_ar' => $bodyAr,
                    'data' => json_encode($data, JSON_UNESCAPED_UNICODE),
                    'sent_via' => 'push,in_app',
                    'created_at' => DB::raw('NOW()'),
                ]);

                $this->push->toAdmin($adminId, $titleAr, $bodyAr, $data);
            }
        } catch (Throwable $e) {
            Log::warning('Employee activation alert failed', [
                'employee_id' => $employee->id,
                'exception' => $e,
            ]);
        }
    }
}
