<?php

declare(strict_types=1);

namespace App\Http\Controllers\Documents;

use App\Domain\Audit\AuditLog;
use App\Domain\Documents\DocumentScope;
use App\Domain\Documents\RequiredDocument;
use App\Exceptions\ApiFailure;
use App\Http\ApiResponse;
use App\Models\Admin;
use App\Support\Value;
use Illuminate\Database\Query\JoinClause;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Ports of api/app/documents/{get_required,create_required,update_required,
 * delete_required,toggle_required,get_required_submissions}.php.
 *
 * The catalogue of documents a company asks for, and who owes each one.
 */
final class RequiredDocumentController
{
    public function index(Request $request): JsonResponse
    {
        return ApiResponse::success([
            'required_documents' => RequiredDocument::catalogue(
                Value::int($request->attributes->get('tenant_id'))
            ),
        ]);
    }

    public function create(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;

        $name = trim(Value::string($request->input('name')));

        if ($name === '') {
            throw new ApiFailure('name is required', 422, 'name_required');
        }

        $fields = ['name' => $name] + self::optionalFields($request);
        $scope = self::scopeType($request) ?? 'all';
        $fields['scope_type'] = $scope;
        $fields['scope_branch_id'] = $scope === 'branch' ? self::branchId($request) : null;

        $employeeIds = $scope === 'employees' ? self::ids($request, 'scope_employee_ids') : [];
        $categoryIds = $scope === 'category' ? self::ids($request, 'scope_category_ids') : [];

        if ($scope === 'employees' && $employeeIds === []) {
            throw new ApiFailure(
                'scope_employee_ids is required when scope_type=employees',
                400,
                'scope_employee_ids_required_scope',
            );
        }

        if ($scope === 'category' && $categoryIds === []) {
            throw new ApiFailure(
                'scope_category_ids is required when scope_type=category',
                400,
                'scope_category_ids_required_scope',
            );
        }

        $id = RequiredDocument::create($tenantId, $fields);

        if ($scope === 'employees') {
            RequiredDocument::setEmployeeScope($id, $tenantId, $employeeIds);
        }

        if ($scope === 'category') {
            RequiredDocument::setCategoryScope($id, $tenantId, $categoryIds);
        }

        AuditLog::record($tenantId, $adminId, 'document_type.create', 'required_document', $id);

        return ApiResponse::success(['required_document_id' => $id], 201);
    }

    public function update(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;
        $id = self::existing($request, $tenantId);

        $fields = self::optionalFields($request);

        if ($request->has('name')) {
            $name = trim(Value::string($request->input('name')));

            if ($name === '') {
                throw new ApiFailure('name is required', 422, 'name_required');
            }

            $fields['name'] = $name;
        }

        $scope = self::scopeType($request);

        if ($scope !== null) {
            $fields['scope_type'] = $scope;
            $fields['scope_branch_id'] = $scope === 'branch' ? self::branchId($request) : null;
        }

        RequiredDocument::update($id, $tenantId, $fields);

        // Changing the scope away from a membership kind clears that membership:
        // a type that used to name six people and is now asked of everybody must
        // not keep six rows that would resurrect if it were narrowed again.
        $this->syncScope($request, $id, $tenantId, $scope, 'employees', 'scope_employee_ids');
        $this->syncScope($request, $id, $tenantId, $scope, 'category', 'scope_category_ids');

        AuditLog::record($tenantId, $adminId, 'document_type.update', 'required_document', $id);

        return ApiResponse::success(['required_document_id' => $id]);
    }

    public function delete(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;
        $id = self::existing($request, $tenantId);

        if (! RequiredDocument::delete($id, $tenantId)) {
            throw new ApiFailure('Failed to delete required document', 500);
        }

        AuditLog::record($tenantId, $adminId, 'document_type.delete', 'required_document', $id);

        return ApiResponse::success(['deleted' => true]);
    }

    public function toggle(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;
        $id = Value::int($request->input('id'));

        $existing = RequiredDocument::find($id, $tenantId);

        if ($existing === null) {
            throw new ApiFailure('Required document not found', 404, 'not_found');
        }

        RequiredDocument::toggleActive($id, $tenantId);

        AuditLog::record($tenantId, $adminId, 'document_type.toggle_active', 'required_document', $id);

        return ApiResponse::success(['is_active' => Value::int($existing['is_active'] ?? null) !== 1]);
    }

    /**
     * Everybody who owes one particular document, whether or not they have
     * handed it in — the review screen's list.
     */
    public function submissions(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $requiredId = Value::int($request->query('required_document_id'));

        $required = RequiredDocument::find($requiredId, $tenantId);

        if ($required === null) {
            throw new ApiFailure('Required document not found', 404, 'not_found');
        }

        // Deliberately not the obligations helper: that one filters to active,
        // required types for the compliance counts. This screen is asked about
        // one named type, and shows its submissions whether it is currently
        // required, optional, or switched off.
        $query = DB::table('employees as e')
            ->join('required_documents as rd', function (JoinClause $join) use ($requiredId): void {
                $join->on('rd.tenant_id', '=', 'e.tenant_id')->where('rd.id', '=', $requiredId);
            })
            ->where('e.tenant_id', $tenantId)
            ->where('e.status', 'active');

        DocumentScope::constrain($query, $tenantId);

        $rows = $query
            ->leftJoin('employee_documents as ed', function (JoinClause $join): void {
                $join->on('ed.employee_id', '=', 'e.id')
                    ->on('ed.required_document_id', '=', 'rd.id')
                    ->on('ed.tenant_id', '=', 'e.tenant_id');
            })
            ->leftJoin('branches as b', 'b.id', '=', 'e.branch_id')
            ->orderBy('e.name')
            ->get([
                'e.id as employee_id', 'e.name as employee_name', 'b.name as branch_name',
                'ed.id as document_id', 'ed.status', 'ed.original_name', 'ed.file_path',
                'ed.mime_type', 'ed.verified_at', 'ed.rejected_reason', 'ed.expires_at',
                'ed.created_at as uploaded_at', 'rd.name as document_name',
            ])
            ->all();

        $submissions = [];

        foreach ($rows as $row) {
            /** @var array<string, mixed> $columns */
            $columns = (array) $row;
            $documentId = Value::nullableInt($columns['document_id'] ?? null);

            $submissions[] = [
                'employee_id' => Value::int($columns['employee_id'] ?? null),
                'employee_name' => $columns['employee_name'] ?? null,
                'branch_name' => $columns['branch_name'] ?? null,
                'document' => $documentId === null ? null : [
                    'id' => $documentId,
                    'employee_id' => Value::int($columns['employee_id'] ?? null),
                    'required_document_id' => $requiredId,
                    'document_name' => $columns['document_name'] ?? null,
                    'status' => $columns['status'] ?? null,
                    'original_name' => $columns['original_name'] ?? null,
                    'file_path' => $columns['file_path'] ?? null,
                    'mime_type' => $columns['mime_type'] ?? null,
                    'verified_at' => $columns['verified_at'] ?? null,
                    'rejected_reason' => $columns['rejected_reason'] ?? null,
                    'expires_at' => $columns['expires_at'] ?? null,
                    'created_at' => $columns['uploaded_at'] ?? null,
                ],
            ];
        }

        return ApiResponse::success([
            'required_document' => [
                'id' => $requiredId,
                'name' => $required['name'] ?? null,
            ],
            'submissions' => $submissions,
        ]);
    }

    private function syncScope(
        Request $request,
        int $id,
        int $tenantId,
        ?string $scope,
        string $kind,
        string $field,
    ): void {
        $setter = $kind === 'employees'
            ? RequiredDocument::setEmployeeScope(...)
            : RequiredDocument::setCategoryScope(...);

        if ($scope === $kind || ($scope === null && $request->has($field))) {
            $setter($id, $tenantId, self::ids($request, $field));

            return;
        }

        if ($scope !== null && $scope !== $kind) {
            $setter($id, $tenantId, []);
        }
    }

    /**
     * @return array<string, mixed>
     */
    private static function optionalFields(Request $request): array
    {
        $fields = [];

        if ($request->has('description')) {
            $fields['description'] = Value::nullableString($request->input('description'));
        }
        if ($request->has('expiry_days')) {
            // Zero means "never expires", which is a null, not a zero-day life.
            $fields['expiry_days'] = Value::int($request->input('expiry_days')) ?: null;
        }
        if ($request->has('notification_days_before')) {
            $fields['notification_days_before'] = Value::int($request->input('notification_days_before'));
        }
        if ($request->has('sort_order')) {
            $fields['sort_order'] = Value::int($request->input('sort_order'));
        }
        if ($request->has('is_required')) {
            $fields['is_required'] = $request->boolean('is_required') ? 1 : 0;
        }
        if ($request->has('category')) {
            $category = Value::string($request->input('category'));

            if (! in_array($category, RequiredDocument::CATEGORIES, true)) {
                throw new ApiFailure('Invalid category', 422, 'invalid_category');
            }

            $fields['category'] = $category;
        }

        return $fields;
    }

    private static function scopeType(Request $request): ?string
    {
        if (! $request->has('scope_type')) {
            return null;
        }

        $scope = Value::string($request->input('scope_type'));

        if (! in_array($scope, RequiredDocument::SCOPES, true)) {
            throw new ApiFailure('Invalid scope_type', 422, 'invalid_scope_type');
        }

        return $scope;
    }

    private static function branchId(Request $request): int
    {
        $branchId = Value::int($request->input('scope_branch_id'));

        if ($branchId <= 0) {
            throw new ApiFailure('scope_branch_id is required', 422, 'scope_branch_id_required');
        }

        return $branchId;
    }

    /**
     * @return list<int>
     */
    private static function ids(Request $request, string $field): array
    {
        $raw = $request->input($field);

        if (! is_array($raw)) {
            return [];
        }

        return array_values(array_filter(
            array_map(static fn (mixed $id): int => Value::int($id), $raw),
            static fn (int $id): bool => $id > 0,
        ));
    }

    private static function existing(Request $request, int $tenantId): int
    {
        $id = Value::int($request->input('id'));

        if (RequiredDocument::find($id, $tenantId) === null) {
            throw new ApiFailure('Required document not found', 404, 'not_found');
        }

        return $id;
    }

    private static function admin(Request $request): Admin
    {
        $admin = $request->attributes->get('admin');

        if (! $admin instanceof Admin) {
            throw new ApiFailure('Authentication required', 401);
        }

        return $admin;
    }
}
