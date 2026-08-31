<?php

declare(strict_types=1);

namespace App\Modules\Employees\Services;

use App\Exceptions\ApiFailure;
use App\Models\ActivationCode;
use App\Modules\Audit\Domain\AuditLog;
use App\Shared\Contact\PhoneValidator;
use App\Support\Value;
use Illuminate\Support\Facades\DB;

/**
 * Adding somebody to a company.
 *
 * More than one insert, because the add-employee form does several things at
 * once: the record, their categories, any recurring allowances agreed at
 * hiring, any documents they are being asked for, and the activation code they
 * need to sign in. Doing them together is the point — an employee created
 * without a code is an employee somebody has to remember to go back to.
 */
final class CreateEmployeeAction
{
    /** @var list<string> */
    public const COMPLIANCE_FIELDS = [
        'nationality',
        'iqama_number', 'iqama_expiry',
        'passport_number', 'passport_expiry',
        'work_permit_number', 'work_permit_expiry',
        'contract_type', 'contract_start', 'contract_end',
        'health_insurance_expiry',
    ];

    /** Matches the weekly_off_days SET column. */
    private const WEEKLY_OFF_DAYS = [
        'saturday', 'sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday',
    ];

    /** @var list<string> */
    private const DOCUMENT_CATEGORIES = ['identity', 'contract', 'certificate', 'insurance', 'general'];

    /**
     * @param  array<array-key, mixed>  $input
     * @return array{employee_id: int, activation_code: string, activation_token: string, join_link: string, phone: string|null}
     *
     * @throws ApiFailure
     */
    public function execute(array $input, int $tenantId, int $adminId): array
    {
        $name = trim(Value::string($input['name'] ?? null));
        $branchId = Value::int($input['branch_id'] ?? null);

        if ($name === '' || $branchId <= 0) {
            throw new ApiFailure('name and branch_id are required', 422, 'missing_fields');
        }

        $phone = $this->phone($input);
        $hireDate = Value::string($input['hire_date'] ?? null, date('Y-m-d'));

        $values = $this->baseValues($input, $tenantId, $branchId, $name, $phone, $hireDate);

        $employeeId = (int) DB::table('employees')->insertGetId($values);

        $this->assignCategories($input, $employeeId, $tenantId);
        $this->createAllowances($input, $employeeId, $tenantId, $adminId, $hireDate);
        $this->requestDocuments($input, $employeeId, $tenantId, $adminId);

        $activation = ActivationCode::generateFor($tenantId, $employeeId);

        AuditLog::record($tenantId, $adminId, 'employee.create', 'employee', $employeeId);

        return [
            'employee_id' => $employeeId,
            'activation_code' => $activation['code'],
            'activation_token' => $activation['token'],
            'join_link' => ActivationCode::joinLink($activation['token']),
            'phone' => $phone,
        ];
    }

    /**
     * @param  array<array-key, mixed>  $input
     * @return array<string, mixed>
     */
    private function baseValues(array $input, int $tenantId, int $branchId, string $name, ?string $phone, string $hireDate): array
    {
        $annualLeave = $input['annual_leave_days'] ?? null;

        $values = [
            'tenant_id' => $tenantId,
            'name' => $name,
            'branch_id' => $branchId,
            'phone' => $phone,
            'job_title' => Value::nullableString($input['job_title'] ?? null),
            'base_salary' => round(Value::float($input['base_salary'] ?? null), 2),
            'hire_date' => $hireDate,
            'work_start_time' => Value::string($input['work_start_time'] ?? null, '09:00:00'),
            'work_end_time' => Value::string($input['work_end_time'] ?? null, '17:00:00'),
            'annual_leave_days' => is_numeric($annualLeave) ? (int) $annualLeave : null,
            'shift_id' => Value::nullableInt($input['shift_id'] ?? null),
            // Not 'active': the record exists but nobody has proved they hold
            // the phone yet.
            'status' => 'pending_activation',
            'national_id' => Value::nullableString($input['national_id'] ?? null),
            'bank_name' => Value::nullableString($input['bank_name'] ?? null),
            'bank_account_number' => Value::nullableString($input['bank_account_number'] ?? null),
            'bank_iban' => Value::nullableString($input['bank_iban'] ?? null),
            'bank_swift' => Value::nullableString($input['bank_swift'] ?? null),
        ];

        if (array_key_exists('weekly_off_days', $input)) {
            $values['weekly_off_days'] = $this->weeklyOffDays($input['weekly_off_days']);
        }

        if (! empty($input['auto_terminate_at'])) {
            $values['auto_terminate_at'] = $this->autoTerminateAt(Value::string($input['auto_terminate_at']));
        }

        foreach (self::COMPLIANCE_FIELDS as $field) {
            $value = $input[$field] ?? null;
            if ($value !== null && $value !== '') {
                $values[$field] = $value;
            }
        }

        $start = Value::nullableString($values['contract_start'] ?? null);
        $end = Value::nullableString($values['contract_end'] ?? null);
        if ($start !== null && $end !== null && $end <= $start) {
            throw new ApiFailure('Contract end must be after the start date', 422, 'contract_end_after_start_date');
        }

        return $values;
    }

    /**
     * @param  array<array-key, mixed>  $input
     */
    private function phone(array $input): ?string
    {
        $phone = trim(Value::string($input['phone'] ?? null));

        if ($phone === '') {
            return null;
        }

        $normalised = PhoneValidator::normalize($phone);
        if ($normalised === null) {
            throw new ApiFailure('Invalid phone number', 422, 'invalid_phone_number');
        }

        return $normalised;
    }

    /**
     * Unknown day names are dropped rather than refused: the column is a SET, so
     * anything not in it would fail at the database with a message nobody can
     * act on.
     */
    private function weeklyOffDays(mixed $value): ?string
    {
        if (is_string($value)) {
            $value = $value === '' ? [] : explode(',', $value);
        }

        if (! is_array($value)) {
            return null;
        }

        $days = array_values(array_unique(array_intersect(
            self::WEEKLY_OFF_DAYS,
            array_map(static fn (mixed $day): string => is_string($day) ? trim($day) : '', $value),
        )));

        return $days === [] ? null : implode(',', $days);
    }

    private function autoTerminateAt(string $date): string
    {
        if (preg_match('/^\d{4}-\d{2}-\d{2}$/', $date) !== 1) {
            throw new ApiFailure('Invalid auto_terminate_at date. Use Y-m-d', 400, 'invalid_date');
        }

        // A fixed-term contract that ends today or earlier is a contradiction:
        // the employee is being created already finished.
        if ($date <= date('Y-m-d')) {
            throw new ApiFailure('auto_terminate_at must be a future date', 422, 'auto_terminate_at_future_date');
        }

        return $date;
    }

    /**
     * @param  array<array-key, mixed>  $input
     */
    private function assignCategories(array $input, int $employeeId, int $tenantId): void
    {
        $ids = $input['category_ids'] ?? null;

        if (! is_array($ids) || $ids === []) {
            return;
        }

        foreach ($ids as $categoryId) {
            $id = Value::int($categoryId);
            if ($id <= 0) {
                continue;
            }

            DB::table('employee_category_assignments')->insertOrIgnore([
                'tenant_id' => $tenantId,
                'employee_id' => $employeeId,
                'category_id' => $id,
            ]);
        }
    }

    /**
     * Recurring monthly allowances agreed at hiring — housing, transport, food.
     *
     * A blank row is skipped rather than refused, so the form can submit a fixed
     * set of optional fields without the caller having to prune them.
     *
     * @param  array<array-key, mixed>  $input
     */
    private function createAllowances(array $input, int $employeeId, int $tenantId, int $adminId, string $hireDate): void
    {
        $allowances = $input['allowances'] ?? null;
        if (! is_array($allowances)) {
            return;
        }

        $defaultStartMonth = substr($hireDate, 0, 7);

        foreach ($allowances as $allowance) {
            if (! is_array($allowance)) {
                continue;
            }

            $type = trim(Value::string($allowance['type'] ?? null));
            $amount = Value::float($allowance['amount'] ?? null);

            if ($type === '' || $amount <= 0) {
                continue;
            }

            $startMonth = Value::string($allowance['start_month'] ?? null);
            if (preg_match('/^\d{4}-\d{2}$/', $startMonth) !== 1) {
                $startMonth = $defaultStartMonth;
            }

            $endMonth = Value::nullableString($allowance['end_month'] ?? null);
            if ($endMonth === '') {
                $endMonth = null;
            }

            if ($endMonth !== null) {
                if (preg_match('/^\d{4}-\d{2}$/', $endMonth) !== 1) {
                    throw new ApiFailure('allowance end_month must be YYYY-MM', 422, 'allowance_end_month_yyyy_mm');
                }
                if ($endMonth < $startMonth) {
                    throw new ApiFailure('allowance end_month cannot be before start_month', 422, 'allowance_end_month_cannot_before');
                }
            }

            $label = trim(Value::string($allowance['label'] ?? null));

            DB::table('employee_allowances')->insert([
                'tenant_id' => $tenantId,
                'employee_id' => $employeeId,
                'type' => $type,
                'amount' => $amount,
                'start_month' => $startMonth,
                'end_month' => $endMonth,
                'label' => $label === '' ? null : $label,
                'created_by' => $adminId,
            ]);
        }
    }

    /**
     * Documents asked of this person only.
     *
     * Employee-scoped rather than a new company-wide requirement: asking one new
     * hire for a certificate must not put it on everybody's checklist.
     *
     * @param  array<array-key, mixed>  $input
     */
    private function requestDocuments(array $input, int $employeeId, int $tenantId, int $adminId): void
    {
        $documents = $input['requested_documents'] ?? null;
        if (! is_array($documents)) {
            return;
        }

        foreach ($documents as $document) {
            if (! is_array($document)) {
                continue;
            }

            $name = trim(Value::string($document['name'] ?? null));
            if ($name === '') {
                continue;
            }

            $category = Value::nullableString($document['category'] ?? null);
            if ($category !== null && $category !== '' && ! in_array($category, self::DOCUMENT_CATEGORIES, true)) {
                throw new ApiFailure('Invalid document category', 422, 'invalid_category');
            }

            $expiryDays = Value::nullableInt($document['expiry_days'] ?? null);
            $description = trim(Value::string($document['description'] ?? null));

            $requiredId = (int) DB::table('required_documents')->insertGetId([
                'tenant_id' => $tenantId,
                'name' => mb_substr($name, 0, 100),
                'description' => $description === '' ? null : $description,
                'category' => $category === '' ? null : $category,
                'expiry_days' => $expiryDays === 0 ? null : $expiryDays,
                'scope_type' => 'employees',
                'scope_branch_id' => null,
                'is_required' => 1,
                'is_active' => 1,
            ]);

            DB::table('required_document_employees')->insert([
                'required_document_id' => $requiredId,
                'employee_id' => $employeeId,
                'tenant_id' => $tenantId,
            ]);

            AuditLog::record($tenantId, $adminId, 'document.request', 'employee', $employeeId, [
                'required_document_id' => $requiredId,
                'custom' => true,
                'source' => 'employee_create',
            ]);
        }
    }
}
