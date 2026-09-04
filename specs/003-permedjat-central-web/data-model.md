# Phase 1 — Data Model: Permedjat Central Web Edition

Entities are **client-side TypeScript types** mirroring the backend JSON returned by the
existing PHP API. They are ported from `frontend/mobile/manager/lib/data/model/*.dart`.
The backend (MySQL) remains the authoritative store; the web client does not own schema.
Field names follow the API's JSON (snake_case) mapped to typed interfaces. Validation
rules listed are client-side form rules (react-hook-form + zod) that match backend
expectations; the backend re-validates.

## Conventions

- All list/detail reads are tenant-scoped (`X-Tenant-Id`); types omit the tenant column.
- IDs are integers unless noted. Money is in EGP (number). Dates are ISO strings or
  `YYYY-MM`/`YYYY-MM-DD` where the API uses month/day granularity.

## Core identity & tenant

- **User / Admin** (`user_model`, `manager_invitation_model` → AdminModel): `id`, `name`,
  `email`, `phone?`, `photo_url?`, `firebase_uid`, `role` (general_manager|hr|
  branch_manager|attendance|viewer), `branch_id?`, `is_active`/`pending`, `tenant_id`,
  `permissions?` (override map). Relationships: belongs to one Company; optionally scoped
  to one Branch.
- **Company (Tenant)**: `id`, `name`, `phone?`, geofence (`lat?`, `lng?`, `radius`),
  `attendance_methods` (subset of qr_gps|gps_only|manual), settings (see Company Settings).
  Owns every other entity.
- **Permission set / Role**: role → default permission map; per-admin override map
  (booleans keyed by permission code, e.g. `manage_attendance`, `add_managers`). General
  Manager is locked (non-editable).

## Employees & people

- **Employee** (`employee_model`): `id`, `name`, `code?`, `email?`, `phone?`,
  `branch_id`, `shift_id?`, `category_id?`, `status` (active|suspended|terminated),
  `base_salary`, `hire_date`, `job_title?`, identity/doc fields, `attendance_method?`
  (override). Has many: Attendance Records, Leave/Break Requests, Documents, Loans,
  Allowances, Warnings, Performance Reviews, Asset custodies, Payslips, Settlement.
  Validation: name ≥ 2 chars; salary ≥ 0; required branch.
- **Terminated Employee** (`terminated_employee_model`): employee + `last_working_day`,
  `termination_reason?`, settlement linkage; supports re-hire (`reactivate`).
- **Suspension** (`suspension_model`): `employee_id`, `from`, `to?`, `reason?`, active flag.
- **Employee Category** (`employee_category_model`): `id`, `name`, `color?`, member count.
- **Biometric Enrollment** (`biometric_enrollment_model`): `employee_id`, `type`
  (face|fingerprint), `enrolled` status, `enrolled_at?`. Web: view + delete only.

## Attendance

- **Attendance Record** (`attendance_model`): `employee_id`, `date`, `status`
  (present|absent|late|leave|holiday), `check_in?`, `check_out?`, `late_minutes`,
  `overtime_minutes`, `note?`. Created/edited via manual recording (admin).
- **Attendance Override** (`attendance_override_model`): per branch/category/employee
  method override (qr_gps|gps_only|manual).
- **Live Attendance** (`live_attendance_model`): real-time board row — employee, current
  status, check-in time, branch; polled every 25s.

## Payroll & money

- **Payslip / Payroll** (`payroll_model`): `employee_id`, `month` (YYYY-MM), `base`,
  `allowances_total`, `bonuses_total`, `deductions_total`, `loan_installment`,
  `net`, `status` (draft|approved|paid), line items. Belongs to a payroll period.
- **Financial Summary** (`financial_summary_model`): per-employee month rollup
  (earnings, deductions, net) + year-to-date.
- **Allowance**: recurring monthly addition (`employee_id`, `type`, `amount`, active).
- **Deduction Rule** (`deduction_rule_model`): tenant-level config + manual
  deduction/bonus entries (`employee_id`, `amount`, `reason`, `month`).
- **Bulk Adjustment** (`bulk_adjustment_model`): tracked batch — `id`, `type`
  (deduction|bonus), `scope` (branch|shift|category|all), `amount`/`formula`, `month`,
  `members[]` (employee ids), `created_by`. Members removable.
- **Loan** (`loan_model`): `id`, `employee_id`, `principal`, `installment`,
  `remaining`, `status` (pending|approved|cancelled|settled), schedule. Repayments feed
  payroll deductions.
- **Settlement / EOSB** (`settlement_model`): `employee_id`, `last_working_day`,
  computed gratuity/leave-encashment/dues, `status` (draft|approved|paid). One per
  terminated employee.

## Time off

- **Leave Request** (`leave_model`): `id`, `employee_id`, `type`, `from`, `to`, `days`,
  `status` (pending|approved|rejected|absence), `reason?`, recurring flag. Affects leave
  balance.
- **Leave Settings / Carryover Policy / Encashment**: tenant policy objects (annual
  entitlement, carryover caps, encashment rules) under Company Settings.
- **Break / Permission Request** (`break_request_model`): `id`, `employee_id`, `date`,
  `from_time`, `to_time`, `status` (pending|approved|rejected|postponed), `reason?`.

## Org structure

- **Branch** (`branch_model`): `id`, `name`, `lat?`, `lng?`, `radius`, `address?`,
  `attendance_methods?` override, employee count, QR token. Filter + assignment target.
- **Shift** (`shift_model`): `id`, `name`, `start`, `end`, `days[]`, members. 
- **Schedule** (`schedule_model`): weekly rotating assignment grid — `week`, per
  employee/day shift assignment, publish state.

## Documents & compliance

- **Document** (`document_model`, `document_submission_model`): `id`, `employee_id`,
  `required_document_id?`, `type`, `file_url`, `status` (pending|verified|rejected),
  `expiry?`, `uploaded_at`.
- **Required Document** (`required_document_model`): tenant-level type — `id`, `name`,
  `required` flag, `expires` flag.
- **Compliance Item** (`compliance_item_model`): document/record with expiry needing
  attention (expiring-soon / expired / missing).
- **Document Report / Stats** (`document_report_model`, `document_stats_model`):
  aggregates for the documents report.

## Assets, discipline, performance

- **Asset Custody** (`asset_custody_model`): `id`, `name`, `employee_id?`, `status`
  (assigned|return_requested|returned), value?. Approve/reject return.
- **Warning** (`warning_model`): `id`, `employee_id`, `reason`, `date`.
- **Performance Review** (`performance_review_model`): `id`, `employee_id`, `period`,
  `rating` (1–5), `notes?`.

## Dashboard & reports

- **Dashboard Overview** (`dashboard_model`): today's counts (present/absent/late/
  on_leave), attendance_rate, branch performance comparison rows, pending leave/break
  counts, payroll summary (net, base, bonuses, deductions, covers), category
  distribution, status lists, expiring compliance.
- **Report** (`report_model`): parameterized period report payloads for attendance,
  payroll, employees, leaves, documents → exportable (PDF/Excel/CSV).

## Cross-cutting

- **Support Ticket / Message** (`support_model`): ticket `id`, `subject`, `status`
  (open|closed), messages[] (`id`, `ticket_id`, `sender`, `body`, `created_at`); polled
  with `after_id` for new replies.
- **Notification**: `id`, `title`, `body`, `read`, `created_at`, `data?` (deep-link).
  Plus preference flags.
- **Audit Log Entry** (`audit_log_model`): `id`, `actor`, `action` (see
  `audit_actions.dart`), `target`, `created_at`.
- **Company Settings**: aggregate of deduction rules, leave settings, statutory payroll
  settings, attendance method, required-documents policy, categories.

## State transitions (key)

- **Employee**: active → suspended → active; active → terminated (with Settlement) →
  reactivated.
- **Payslip**: draft → approved → paid (revertible to draft).
- **Leave**: pending → approved | rejected | converted-to-absence.
- **Break**: pending → approved | rejected | postponed.
- **Loan**: pending → approved → settled | cancelled.
- **Settlement**: draft → approved → paid.
- **Asset**: assigned → return_requested → returned (or rejected back to assigned).
- **Document**: pending → verified | rejected; verified → expired (by date).
