<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Every foreign key in the schema, applied after all tables exist.
 *
 * Keeping them here rather than inline means table migrations never have to be
 * ordered by dependency — a graph that is tedious to maintain by hand and easy
 * to break with a single new relation.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('admin_devices', function (Blueprint $table): void {
            $table->foreign(['admin_id'], 'admin_devices_ibfk_1')->references(['id'])->on('admins')->cascadeOnDelete();
        });
        Schema::table('admin_notification_prefs', function (Blueprint $table): void {
            $table->foreign(['admin_id'], 'admin_notification_prefs_ibfk_1')->references(['id'])->on('admins')->cascadeOnDelete();
        });
        Schema::table('admins', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'admins_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
            $table->foreign(['branch_id'], 'admins_ibfk_2')->references(['id'])->on('branches')->nullOnDelete();
        });
        Schema::table('approval_chain_steps', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'approval_chain_steps_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
            $table->foreign(['chain_id'], 'approval_chain_steps_ibfk_2')->references(['id'])->on('approval_chains')->cascadeOnDelete();
            $table->foreign(['approver_admin_id'], 'approval_chain_steps_ibfk_3')->references(['id'])->on('admins')->nullOnDelete();
        });
        Schema::table('approval_chains', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'approval_chains_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
            $table->foreign(['branch_id'], 'approval_chains_ibfk_2')->references(['id'])->on('branches')->cascadeOnDelete();
            $table->foreign(['created_by'], 'approval_chains_ibfk_3')->references(['id'])->on('admins')->nullOnDelete();
        });
        Schema::table('approval_request_steps', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'approval_request_steps_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
            $table->foreign(['request_id'], 'approval_request_steps_ibfk_2')->references(['id'])->on('approval_requests')->cascadeOnDelete();
            $table->foreign(['approver_admin_id'], 'approval_request_steps_ibfk_3')->references(['id'])->on('admins')->nullOnDelete();
        });
        Schema::table('approval_requests', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'approval_requests_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
            $table->foreign(['chain_id'], 'approval_requests_ibfk_2')->references(['id'])->on('approval_chains')->nullOnDelete();
        });
        Schema::table('asset_custody', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'asset_custody_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
            $table->foreign(['employee_id'], 'asset_custody_ibfk_2')->references(['id'])->on('employees')->cascadeOnDelete();
            $table->foreign(['assigned_by'], 'asset_custody_ibfk_3')->references(['id'])->on('admins')->nullOnDelete();
            $table->foreign(['return_approved_by'], 'asset_custody_ibfk_4')->references(['id'])->on('admins')->nullOnDelete();
        });
        Schema::table('attendance', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'attendance_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
            $table->foreign(['branch_id'], 'attendance_ibfk_2')->references(['id'])->on('branches')->nullOnDelete();
            $table->foreign(['employee_id'], 'attendance_ibfk_3')->references(['id'])->on('employees')->cascadeOnDelete();
            $table->foreign(['recorded_by'], 'attendance_ibfk_4')->references(['id'])->on('admins')->nullOnDelete();
            $table->foreign(['recorded_by_employee_id'], 'attendance_recorded_by_employee_fk')->references(['id'])->on('employees')->nullOnDelete();
        });
        Schema::table('attendance_security_logs', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'seclog_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
            $table->foreign(['employee_id'], 'seclog_ibfk_2')->references(['id'])->on('employees')->cascadeOnDelete();
        });
        Schema::table('attendance_stations', function (Blueprint $table): void {
            $table->foreign(['branch_id'], 'station_ibfk_branch')->references(['id'])->on('branches')->cascadeOnDelete();
            $table->foreign(['tenant_id'], 'station_ibfk_tenant')->references(['id'])->on('tenants')->cascadeOnDelete();
        });
        Schema::table('audit_log', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'audit_log_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
            $table->foreign(['admin_id'], 'audit_log_ibfk_2')->references(['id'])->on('admins')->nullOnDelete();
        });
        Schema::table('bonus_rules', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'bonus_rules_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
        });
        Schema::table('branch_qr_challenges', function (Blueprint $table): void {
            $table->foreign(['branch_id'], 'branch_qr_challenges_branch_fk')->references(['id'])->on('branches')->cascadeOnDelete();
            $table->foreign(['tenant_id'], 'branch_qr_challenges_tenant_fk')->references(['id'])->on('tenants')->cascadeOnDelete();
        });
        Schema::table('branch_qr_uses', function (Blueprint $table): void {
            $table->foreign(['challenge_id'], 'branch_qr_uses_challenge_fk')->references(['id'])->on('branch_qr_challenges')->cascadeOnDelete();
            $table->foreign(['employee_id'], 'branch_qr_uses_employee_fk')->references(['id'])->on('employees')->cascadeOnDelete();
        });
        Schema::table('branches', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'branches_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
        });
        Schema::table('break_requests', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'break_requests_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
            $table->foreign(['employee_id'], 'break_requests_ibfk_2')->references(['id'])->on('employees')->cascadeOnDelete();
            $table->foreign(['decided_by'], 'break_requests_ibfk_3')->references(['id'])->on('admins')->nullOnDelete();
        });
        Schema::table('bulk_adjustments', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'bulk_adjustments_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
            $table->foreign(['created_by'], 'bulk_adjustments_ibfk_2')->references(['id'])->on('admins')->nullOnDelete();
        });
        Schema::table('candidates', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'candidates_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
            $table->foreign(['job_opening_id'], 'candidates_ibfk_2')->references(['id'])->on('job_openings')->nullOnDelete();
            $table->foreign(['converted_employee_id'], 'candidates_ibfk_3')->references(['id'])->on('employees')->nullOnDelete();
            $table->foreign(['created_by'], 'candidates_ibfk_4')->references(['id'])->on('admins')->nullOnDelete();
        });
        Schema::table('custom_roles', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'custom_roles_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
            $table->foreign(['admin_id'], 'custom_roles_ibfk_2')->references(['id'])->on('admins')->cascadeOnDelete();
            $table->foreign(['branch_id'], 'custom_roles_ibfk_3')->references(['id'])->on('branches')->nullOnDelete();
        });
        Schema::table('deduction_rules', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'deduction_rules_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
        });
        Schema::table('desktop_auth_codes', function (Blueprint $table): void {
            $table->foreign(['admin_id'], 'fk_desktop_auth_admin')->references(['id'])->on('admins')->cascadeOnDelete();
        });
        Schema::table('employee_activation_codes', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'employee_activation_codes_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
            $table->foreign(['employee_id'], 'employee_activation_codes_ibfk_2')->references(['id'])->on('employees')->cascadeOnDelete();
        });
        Schema::table('employee_allowances', function (Blueprint $table): void {
            $table->foreign(['created_by'], 'fk_alw_admin')->references(['id'])->on('admins')->nullOnDelete();
            $table->foreign(['employee_id'], 'fk_alw_employee')->references(['id'])->on('employees')->cascadeOnDelete();
            $table->foreign(['tenant_id'], 'fk_alw_tenant')->references(['id'])->on('tenants')->cascadeOnDelete();
        });
        Schema::table('employee_auth_tokens', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'employee_auth_tokens_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
            $table->foreign(['employee_id'], 'employee_auth_tokens_ibfk_2')->references(['id'])->on('employees')->cascadeOnDelete();
        });
        Schema::table('employee_availability', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'employee_availability_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
            $table->foreign(['employee_id'], 'employee_availability_ibfk_2')->references(['id'])->on('employees')->cascadeOnDelete();
        });
        Schema::table('employee_categories', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'employee_categories_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
        });
        Schema::table('employee_category_assignments', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'employee_category_assignments_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
            $table->foreign(['employee_id'], 'employee_category_assignments_ibfk_2')->references(['id'])->on('employees')->cascadeOnDelete();
            $table->foreign(['category_id'], 'employee_category_assignments_ibfk_3')->references(['id'])->on('employee_categories')->cascadeOnDelete();
        });
        Schema::table('employee_documents', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'employee_documents_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
            $table->foreign(['employee_id'], 'employee_documents_ibfk_2')->references(['id'])->on('employees')->cascadeOnDelete();
            $table->foreign(['required_document_id'], 'employee_documents_ibfk_3')->references(['id'])->on('required_documents')->nullOnDelete();
            $table->foreign(['uploaded_by'], 'employee_documents_ibfk_4')->references(['id'])->on('admins')->nullOnDelete();
        });
        Schema::table('employee_loans', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'employee_loans_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
            $table->foreign(['employee_id'], 'employee_loans_ibfk_2')->references(['id'])->on('employees')->cascadeOnDelete();
            $table->foreign(['created_by'], 'employee_loans_ibfk_3')->references(['id'])->on('admins')->nullOnDelete();
            $table->foreign(['approved_by'], 'employee_loans_ibfk_4')->references(['id'])->on('admins')->nullOnDelete();
        });
        Schema::table('employee_settlements', function (Blueprint $table): void {
            $table->foreign(['approved_by'], 'fk_settlement_approved_by')->references(['id'])->on('admins')->nullOnDelete();
            $table->foreign(['created_by'], 'fk_settlement_created_by')->references(['id'])->on('admins')->nullOnDelete();
            $table->foreign(['employee_id'], 'fk_settlement_employee')->references(['id'])->on('employees')->cascadeOnDelete();
            $table->foreign(['tenant_id'], 'fk_settlement_tenant')->references(['id'])->on('tenants')->cascadeOnDelete();
        });
        Schema::table('employee_shift_schedule', function (Blueprint $table): void {
            $table->foreign(['created_by'], 'fk_sched_admin')->references(['id'])->on('admins')->nullOnDelete();
            $table->foreign(['employee_id'], 'fk_sched_employee')->references(['id'])->on('employees')->cascadeOnDelete();
            $table->foreign(['shift_id'], 'fk_sched_shift')->references(['id'])->on('shifts')->cascadeOnDelete();
            $table->foreign(['tenant_id'], 'fk_sched_tenant')->references(['id'])->on('tenants')->cascadeOnDelete();
        });
        Schema::table('employee_suspensions', function (Blueprint $table): void {
            $table->foreign(['created_by'], 'fk_susp_created_by')->references(['id'])->on('admins')->nullOnDelete();
            $table->foreign(['employee_id'], 'fk_susp_employee')->references(['id'])->on('employees')->cascadeOnDelete();
            $table->foreign(['ended_by'], 'fk_susp_ended_by')->references(['id'])->on('admins')->nullOnDelete();
            $table->foreign(['tenant_id'], 'fk_susp_tenant')->references(['id'])->on('tenants')->cascadeOnDelete();
        });
        Schema::table('employees', function (Blueprint $table): void {
            $table->foreign(['crew_supervisor_id'], 'employees_crew_supervisor_fk')->references(['id'])->on('employees')->nullOnDelete();
            $table->foreign(['tenant_id'], 'employees_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
            $table->foreign(['branch_id'], 'employees_ibfk_2')->references(['id'])->on('branches')->nullOnDelete();
            $table->foreign(['admin_id'], 'employees_ibfk_3')->references(['id'])->on('admins')->nullOnDelete();
            $table->foreign(['shift_id'], 'fk_emp_shift')->references(['id'])->on('shifts')->nullOnDelete();
        });
        Schema::table('holidays', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'holidays_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
            $table->foreign(['branch_id'], 'holidays_ibfk_2')->references(['id'])->on('branches')->cascadeOnDelete();
            $table->foreign(['created_by'], 'holidays_ibfk_3')->references(['id'])->on('admins')->nullOnDelete();
        });
        Schema::table('job_openings', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'job_openings_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
            $table->foreign(['branch_id'], 'job_openings_ibfk_2')->references(['id'])->on('branches')->nullOnDelete();
            $table->foreign(['created_by'], 'job_openings_ibfk_3')->references(['id'])->on('admins')->nullOnDelete();
        });
        Schema::table('kiosk_auth_tokens', function (Blueprint $table): void {
            $table->foreign(['station_id'], 'kiosk_token_ibfk_station')->references(['id'])->on('attendance_stations')->cascadeOnDelete();
            $table->foreign(['tenant_id'], 'kiosk_token_ibfk_tenant')->references(['id'])->on('tenants')->cascadeOnDelete();
        });
        Schema::table('kiosk_codes', function (Blueprint $table): void {
            $table->foreign(['branch_id'], 'kiosk_code_ibfk_branch')->references(['id'])->on('branches')->cascadeOnDelete();
            $table->foreign(['tenant_id'], 'kiosk_code_ibfk_tenant')->references(['id'])->on('tenants')->cascadeOnDelete();
        });
        Schema::table('late_deduction_tiers', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'late_deduction_tiers_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
        });
        Schema::table('leave_carryover_policies', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'fk_lcp_tenant')->references(['id'])->on('tenants')->cascadeOnDelete();
        });
        Schema::table('leave_encashments', function (Blueprint $table): void {
            $table->foreign(['employee_id'], 'fk_enc_employee')->references(['id'])->on('employees')->cascadeOnDelete();
            $table->foreign(['tenant_id'], 'fk_enc_tenant')->references(['id'])->on('tenants')->cascadeOnDelete();
        });
        Schema::table('leave_year_balances', function (Blueprint $table): void {
            $table->foreign(['employee_id'], 'fk_lyb_employee')->references(['id'])->on('employees')->cascadeOnDelete();
            $table->foreign(['tenant_id'], 'fk_lyb_tenant')->references(['id'])->on('tenants')->cascadeOnDelete();
        });
        Schema::table('leaves', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'leaves_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
            $table->foreign(['employee_id'], 'leaves_ibfk_2')->references(['id'])->on('employees')->cascadeOnDelete();
            $table->foreign(['approved_by'], 'leaves_ibfk_3')->references(['id'])->on('admins')->nullOnDelete();
            $table->foreign(['rejected_by'], 'leaves_ibfk_4')->references(['id'])->on('admins')->nullOnDelete();
        });
        Schema::table('loan_installments', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'loan_installments_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
            $table->foreign(['loan_id'], 'loan_installments_ibfk_2')->references(['id'])->on('employee_loans')->cascadeOnDelete();
            $table->foreign(['employee_id'], 'loan_installments_ibfk_3')->references(['id'])->on('employees')->cascadeOnDelete();
        });
        Schema::table('manager_invitations', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'manager_invitations_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
            $table->foreign(['branch_id'], 'manager_invitations_ibfk_2')->references(['id'])->on('branches')->nullOnDelete();
            $table->foreign(['invited_by'], 'manager_invitations_ibfk_3')->references(['id'])->on('admins')->nullOnDelete();
            $table->foreign(['accepted_admin_id'], 'manager_invitations_ibfk_4')->references(['id'])->on('admins')->nullOnDelete();
        });
        Schema::table('manual_bonuses', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'manual_bonuses_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
            $table->foreign(['employee_id'], 'manual_bonuses_ibfk_2')->references(['id'])->on('employees')->cascadeOnDelete();
            $table->foreign(['created_by'], 'manual_bonuses_ibfk_3')->references(['id'])->on('admins')->nullOnDelete();
            $table->foreign(['batch_id'], 'manual_bonuses_ibfk_batch')->references(['id'])->on('bulk_adjustments')->nullOnDelete();
        });
        Schema::table('manual_deductions', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'manual_deductions_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
            $table->foreign(['employee_id'], 'manual_deductions_ibfk_2')->references(['id'])->on('employees')->cascadeOnDelete();
            $table->foreign(['created_by'], 'manual_deductions_ibfk_3')->references(['id'])->on('admins')->nullOnDelete();
            $table->foreign(['batch_id'], 'manual_deductions_ibfk_batch')->references(['id'])->on('bulk_adjustments')->nullOnDelete();
        });
        Schema::table('notifications', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'notifications_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
            $table->foreign(['admin_id'], 'notifications_ibfk_2')->references(['id'])->on('admins')->cascadeOnDelete();
            $table->foreign(['employee_id'], 'notifications_ibfk_3')->references(['id'])->on('employees')->cascadeOnDelete();
        });
        Schema::table('onboarding_tasks', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'onboarding_tasks_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
            $table->foreign(['employee_id'], 'onboarding_tasks_ibfk_2')->references(['id'])->on('employees')->cascadeOnDelete();
            $table->foreign(['template_id'], 'onboarding_tasks_ibfk_3')->references(['id'])->on('onboarding_templates')->nullOnDelete();
            $table->foreign(['completed_by'], 'onboarding_tasks_ibfk_4')->references(['id'])->on('admins')->nullOnDelete();
        });
        Schema::table('onboarding_templates', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'onboarding_templates_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
        });
        Schema::table('open_shift_claims', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'open_shift_claims_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
            $table->foreign(['open_shift_id'], 'open_shift_claims_ibfk_2')->references(['id'])->on('open_shifts')->cascadeOnDelete();
            $table->foreign(['employee_id'], 'open_shift_claims_ibfk_3')->references(['id'])->on('employees')->cascadeOnDelete();
            $table->foreign(['decided_by'], 'open_shift_claims_ibfk_4')->references(['id'])->on('admins')->nullOnDelete();
        });
        Schema::table('open_shifts', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'open_shifts_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
            $table->foreign(['shift_id'], 'open_shifts_ibfk_2')->references(['id'])->on('shifts')->cascadeOnDelete();
            $table->foreign(['branch_id'], 'open_shifts_ibfk_3')->references(['id'])->on('branches')->cascadeOnDelete();
            $table->foreign(['created_by'], 'open_shifts_ibfk_4')->references(['id'])->on('admins')->nullOnDelete();
        });
        Schema::table('payroll', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'payroll_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
            $table->foreign(['employee_id'], 'payroll_ibfk_2')->references(['id'])->on('employees')->cascadeOnDelete();
            $table->foreign(['branch_id'], 'payroll_ibfk_3')->references(['id'])->on('branches')->nullOnDelete();
            $table->foreign(['approved_by'], 'payroll_ibfk_4')->references(['id'])->on('admins')->nullOnDelete();
        });
        Schema::table('payroll_line_overrides', function (Blueprint $table): void {
            $table->foreign(['created_by'], 'fk_plo_created_by')->references(['id'])->on('admins')->nullOnDelete();
            $table->foreign(['employee_id'], 'fk_plo_employee')->references(['id'])->on('employees')->cascadeOnDelete();
            $table->foreign(['tenant_id'], 'fk_plo_tenant')->references(['id'])->on('tenants')->cascadeOnDelete();
        });
        Schema::table('payroll_statutory_settings', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'fk_statutory_tenant')->references(['id'])->on('tenants')->cascadeOnDelete();
        });
        Schema::table('performance_cycles', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'performance_cycles_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
            $table->foreign(['created_by'], 'performance_cycles_ibfk_2')->references(['id'])->on('admins')->nullOnDelete();
        });
        Schema::table('performance_goals', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'performance_goals_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
            $table->foreign(['employee_id'], 'performance_goals_ibfk_2')->references(['id'])->on('employees')->cascadeOnDelete();
            $table->foreign(['cycle_id'], 'performance_goals_ibfk_3')->references(['id'])->on('performance_cycles')->nullOnDelete();
            $table->foreign(['created_by'], 'performance_goals_ibfk_4')->references(['id'])->on('admins')->nullOnDelete();
        });
        Schema::table('performance_reviews', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'performance_reviews_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
            $table->foreign(['employee_id'], 'performance_reviews_ibfk_2')->references(['id'])->on('employees')->cascadeOnDelete();
            $table->foreign(['cycle_id'], 'performance_reviews_ibfk_3')->references(['id'])->on('performance_cycles')->nullOnDelete();
            $table->foreign(['reviewer_id'], 'performance_reviews_ibfk_4')->references(['id'])->on('admins')->nullOnDelete();
        });
        Schema::table('recurring_leaves', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'recurring_leaves_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
            $table->foreign(['branch_id'], 'recurring_leaves_ibfk_2')->references(['id'])->on('branches')->nullOnDelete();
        });
        Schema::table('required_document_categories', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'required_document_categories_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
            $table->foreign(['required_document_id'], 'required_document_categories_ibfk_2')->references(['id'])->on('required_documents')->cascadeOnDelete();
            $table->foreign(['category_id'], 'required_document_categories_ibfk_3')->references(['id'])->on('employee_categories')->cascadeOnDelete();
        });
        Schema::table('required_document_employees', function (Blueprint $table): void {
            $table->foreign(['required_document_id'], 'required_document_employees_ibfk_1')->references(['id'])->on('required_documents')->cascadeOnDelete();
            $table->foreign(['employee_id'], 'required_document_employees_ibfk_2')->references(['id'])->on('employees')->cascadeOnDelete();
            $table->foreign(['tenant_id'], 'required_document_employees_ibfk_3')->references(['id'])->on('tenants')->cascadeOnDelete();
        });
        Schema::table('required_documents', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'required_documents_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
        });
        Schema::table('shifts', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'shifts_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
            $table->foreign(['branch_id'], 'shifts_ibfk_2')->references(['id'])->on('branches')->nullOnDelete();
        });
        Schema::table('station_recognition_logs', function (Blueprint $table): void {
            $table->foreign(['station_id'], 'srl_ibfk_station')->references(['id'])->on('attendance_stations')->cascadeOnDelete();
            $table->foreign(['tenant_id'], 'srl_ibfk_tenant')->references(['id'])->on('tenants')->cascadeOnDelete();
        });
        Schema::table('super_admin_audit_log', function (Blueprint $table): void {
            $table->foreign(['admin_id'], 'super_admin_audit_log_ibfk_1')->references(['id'])->on('super_admins')->nullOnDelete();
        });
        Schema::table('super_admin_devices', function (Blueprint $table): void {
            $table->foreign(['admin_id'], 'fk_super_admin_devices_admin')->references(['id'])->on('super_admins')->cascadeOnDelete();
        });
        Schema::table('super_admin_sessions', function (Blueprint $table): void {
            $table->foreign(['admin_id'], 'super_admin_sessions_ibfk_1')->references(['id'])->on('super_admins')->cascadeOnDelete();
        });
        Schema::table('support_messages', function (Blueprint $table): void {
            $table->foreign(['ticket_id'], 'support_messages_ibfk_1')->references(['id'])->on('support_tickets')->cascadeOnDelete();
        });
        Schema::table('support_tickets', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'support_tickets_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
            $table->foreign(['opened_by_admin_id'], 'support_tickets_ibfk_2')->references(['id'])->on('admins')->cascadeOnDelete();
        });
        Schema::table('warnings', function (Blueprint $table): void {
            $table->foreign(['tenant_id'], 'warnings_ibfk_1')->references(['id'])->on('tenants')->cascadeOnDelete();
            $table->foreign(['employee_id'], 'warnings_ibfk_2')->references(['id'])->on('employees')->cascadeOnDelete();
            $table->foreign(['issued_by'], 'warnings_ibfk_3')->references(['id'])->on('admins')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('admin_devices', function (Blueprint $table): void {
            $table->dropForeign('admin_devices_ibfk_1');
        });
        Schema::table('admin_notification_prefs', function (Blueprint $table): void {
            $table->dropForeign('admin_notification_prefs_ibfk_1');
        });
        Schema::table('admins', function (Blueprint $table): void {
            $table->dropForeign('admins_ibfk_1');
            $table->dropForeign('admins_ibfk_2');
        });
        Schema::table('approval_chain_steps', function (Blueprint $table): void {
            $table->dropForeign('approval_chain_steps_ibfk_1');
            $table->dropForeign('approval_chain_steps_ibfk_2');
            $table->dropForeign('approval_chain_steps_ibfk_3');
        });
        Schema::table('approval_chains', function (Blueprint $table): void {
            $table->dropForeign('approval_chains_ibfk_1');
            $table->dropForeign('approval_chains_ibfk_2');
            $table->dropForeign('approval_chains_ibfk_3');
        });
        Schema::table('approval_request_steps', function (Blueprint $table): void {
            $table->dropForeign('approval_request_steps_ibfk_1');
            $table->dropForeign('approval_request_steps_ibfk_2');
            $table->dropForeign('approval_request_steps_ibfk_3');
        });
        Schema::table('approval_requests', function (Blueprint $table): void {
            $table->dropForeign('approval_requests_ibfk_1');
            $table->dropForeign('approval_requests_ibfk_2');
        });
        Schema::table('asset_custody', function (Blueprint $table): void {
            $table->dropForeign('asset_custody_ibfk_1');
            $table->dropForeign('asset_custody_ibfk_2');
            $table->dropForeign('asset_custody_ibfk_3');
            $table->dropForeign('asset_custody_ibfk_4');
        });
        Schema::table('attendance', function (Blueprint $table): void {
            $table->dropForeign('attendance_ibfk_1');
            $table->dropForeign('attendance_ibfk_2');
            $table->dropForeign('attendance_ibfk_3');
            $table->dropForeign('attendance_ibfk_4');
            $table->dropForeign('attendance_recorded_by_employee_fk');
        });
        Schema::table('attendance_security_logs', function (Blueprint $table): void {
            $table->dropForeign('seclog_ibfk_1');
            $table->dropForeign('seclog_ibfk_2');
        });
        Schema::table('attendance_stations', function (Blueprint $table): void {
            $table->dropForeign('station_ibfk_branch');
            $table->dropForeign('station_ibfk_tenant');
        });
        Schema::table('audit_log', function (Blueprint $table): void {
            $table->dropForeign('audit_log_ibfk_1');
            $table->dropForeign('audit_log_ibfk_2');
        });
        Schema::table('bonus_rules', function (Blueprint $table): void {
            $table->dropForeign('bonus_rules_ibfk_1');
        });
        Schema::table('branch_qr_challenges', function (Blueprint $table): void {
            $table->dropForeign('branch_qr_challenges_branch_fk');
            $table->dropForeign('branch_qr_challenges_tenant_fk');
        });
        Schema::table('branch_qr_uses', function (Blueprint $table): void {
            $table->dropForeign('branch_qr_uses_challenge_fk');
            $table->dropForeign('branch_qr_uses_employee_fk');
        });
        Schema::table('branches', function (Blueprint $table): void {
            $table->dropForeign('branches_ibfk_1');
        });
        Schema::table('break_requests', function (Blueprint $table): void {
            $table->dropForeign('break_requests_ibfk_1');
            $table->dropForeign('break_requests_ibfk_2');
            $table->dropForeign('break_requests_ibfk_3');
        });
        Schema::table('bulk_adjustments', function (Blueprint $table): void {
            $table->dropForeign('bulk_adjustments_ibfk_1');
            $table->dropForeign('bulk_adjustments_ibfk_2');
        });
        Schema::table('candidates', function (Blueprint $table): void {
            $table->dropForeign('candidates_ibfk_1');
            $table->dropForeign('candidates_ibfk_2');
            $table->dropForeign('candidates_ibfk_3');
            $table->dropForeign('candidates_ibfk_4');
        });
        Schema::table('custom_roles', function (Blueprint $table): void {
            $table->dropForeign('custom_roles_ibfk_1');
            $table->dropForeign('custom_roles_ibfk_2');
            $table->dropForeign('custom_roles_ibfk_3');
        });
        Schema::table('deduction_rules', function (Blueprint $table): void {
            $table->dropForeign('deduction_rules_ibfk_1');
        });
        Schema::table('desktop_auth_codes', function (Blueprint $table): void {
            $table->dropForeign('fk_desktop_auth_admin');
        });
        Schema::table('employee_activation_codes', function (Blueprint $table): void {
            $table->dropForeign('employee_activation_codes_ibfk_1');
            $table->dropForeign('employee_activation_codes_ibfk_2');
        });
        Schema::table('employee_allowances', function (Blueprint $table): void {
            $table->dropForeign('fk_alw_admin');
            $table->dropForeign('fk_alw_employee');
            $table->dropForeign('fk_alw_tenant');
        });
        Schema::table('employee_auth_tokens', function (Blueprint $table): void {
            $table->dropForeign('employee_auth_tokens_ibfk_1');
            $table->dropForeign('employee_auth_tokens_ibfk_2');
        });
        Schema::table('employee_availability', function (Blueprint $table): void {
            $table->dropForeign('employee_availability_ibfk_1');
            $table->dropForeign('employee_availability_ibfk_2');
        });
        Schema::table('employee_categories', function (Blueprint $table): void {
            $table->dropForeign('employee_categories_ibfk_1');
        });
        Schema::table('employee_category_assignments', function (Blueprint $table): void {
            $table->dropForeign('employee_category_assignments_ibfk_1');
            $table->dropForeign('employee_category_assignments_ibfk_2');
            $table->dropForeign('employee_category_assignments_ibfk_3');
        });
        Schema::table('employee_documents', function (Blueprint $table): void {
            $table->dropForeign('employee_documents_ibfk_1');
            $table->dropForeign('employee_documents_ibfk_2');
            $table->dropForeign('employee_documents_ibfk_3');
            $table->dropForeign('employee_documents_ibfk_4');
        });
        Schema::table('employee_loans', function (Blueprint $table): void {
            $table->dropForeign('employee_loans_ibfk_1');
            $table->dropForeign('employee_loans_ibfk_2');
            $table->dropForeign('employee_loans_ibfk_3');
            $table->dropForeign('employee_loans_ibfk_4');
        });
        Schema::table('employee_settlements', function (Blueprint $table): void {
            $table->dropForeign('fk_settlement_approved_by');
            $table->dropForeign('fk_settlement_created_by');
            $table->dropForeign('fk_settlement_employee');
            $table->dropForeign('fk_settlement_tenant');
        });
        Schema::table('employee_shift_schedule', function (Blueprint $table): void {
            $table->dropForeign('fk_sched_admin');
            $table->dropForeign('fk_sched_employee');
            $table->dropForeign('fk_sched_shift');
            $table->dropForeign('fk_sched_tenant');
        });
        Schema::table('employee_suspensions', function (Blueprint $table): void {
            $table->dropForeign('fk_susp_created_by');
            $table->dropForeign('fk_susp_employee');
            $table->dropForeign('fk_susp_ended_by');
            $table->dropForeign('fk_susp_tenant');
        });
        Schema::table('employees', function (Blueprint $table): void {
            $table->dropForeign('employees_crew_supervisor_fk');
            $table->dropForeign('employees_ibfk_1');
            $table->dropForeign('employees_ibfk_2');
            $table->dropForeign('employees_ibfk_3');
            $table->dropForeign('fk_emp_shift');
        });
        Schema::table('holidays', function (Blueprint $table): void {
            $table->dropForeign('holidays_ibfk_1');
            $table->dropForeign('holidays_ibfk_2');
            $table->dropForeign('holidays_ibfk_3');
        });
        Schema::table('job_openings', function (Blueprint $table): void {
            $table->dropForeign('job_openings_ibfk_1');
            $table->dropForeign('job_openings_ibfk_2');
            $table->dropForeign('job_openings_ibfk_3');
        });
        Schema::table('kiosk_auth_tokens', function (Blueprint $table): void {
            $table->dropForeign('kiosk_token_ibfk_station');
            $table->dropForeign('kiosk_token_ibfk_tenant');
        });
        Schema::table('kiosk_codes', function (Blueprint $table): void {
            $table->dropForeign('kiosk_code_ibfk_branch');
            $table->dropForeign('kiosk_code_ibfk_tenant');
        });
        Schema::table('late_deduction_tiers', function (Blueprint $table): void {
            $table->dropForeign('late_deduction_tiers_ibfk_1');
        });
        Schema::table('leave_carryover_policies', function (Blueprint $table): void {
            $table->dropForeign('fk_lcp_tenant');
        });
        Schema::table('leave_encashments', function (Blueprint $table): void {
            $table->dropForeign('fk_enc_employee');
            $table->dropForeign('fk_enc_tenant');
        });
        Schema::table('leave_year_balances', function (Blueprint $table): void {
            $table->dropForeign('fk_lyb_employee');
            $table->dropForeign('fk_lyb_tenant');
        });
        Schema::table('leaves', function (Blueprint $table): void {
            $table->dropForeign('leaves_ibfk_1');
            $table->dropForeign('leaves_ibfk_2');
            $table->dropForeign('leaves_ibfk_3');
            $table->dropForeign('leaves_ibfk_4');
        });
        Schema::table('loan_installments', function (Blueprint $table): void {
            $table->dropForeign('loan_installments_ibfk_1');
            $table->dropForeign('loan_installments_ibfk_2');
            $table->dropForeign('loan_installments_ibfk_3');
        });
        Schema::table('manager_invitations', function (Blueprint $table): void {
            $table->dropForeign('manager_invitations_ibfk_1');
            $table->dropForeign('manager_invitations_ibfk_2');
            $table->dropForeign('manager_invitations_ibfk_3');
            $table->dropForeign('manager_invitations_ibfk_4');
        });
        Schema::table('manual_bonuses', function (Blueprint $table): void {
            $table->dropForeign('manual_bonuses_ibfk_1');
            $table->dropForeign('manual_bonuses_ibfk_2');
            $table->dropForeign('manual_bonuses_ibfk_3');
            $table->dropForeign('manual_bonuses_ibfk_batch');
        });
        Schema::table('manual_deductions', function (Blueprint $table): void {
            $table->dropForeign('manual_deductions_ibfk_1');
            $table->dropForeign('manual_deductions_ibfk_2');
            $table->dropForeign('manual_deductions_ibfk_3');
            $table->dropForeign('manual_deductions_ibfk_batch');
        });
        Schema::table('notifications', function (Blueprint $table): void {
            $table->dropForeign('notifications_ibfk_1');
            $table->dropForeign('notifications_ibfk_2');
            $table->dropForeign('notifications_ibfk_3');
        });
        Schema::table('onboarding_tasks', function (Blueprint $table): void {
            $table->dropForeign('onboarding_tasks_ibfk_1');
            $table->dropForeign('onboarding_tasks_ibfk_2');
            $table->dropForeign('onboarding_tasks_ibfk_3');
            $table->dropForeign('onboarding_tasks_ibfk_4');
        });
        Schema::table('onboarding_templates', function (Blueprint $table): void {
            $table->dropForeign('onboarding_templates_ibfk_1');
        });
        Schema::table('open_shift_claims', function (Blueprint $table): void {
            $table->dropForeign('open_shift_claims_ibfk_1');
            $table->dropForeign('open_shift_claims_ibfk_2');
            $table->dropForeign('open_shift_claims_ibfk_3');
            $table->dropForeign('open_shift_claims_ibfk_4');
        });
        Schema::table('open_shifts', function (Blueprint $table): void {
            $table->dropForeign('open_shifts_ibfk_1');
            $table->dropForeign('open_shifts_ibfk_2');
            $table->dropForeign('open_shifts_ibfk_3');
            $table->dropForeign('open_shifts_ibfk_4');
        });
        Schema::table('payroll', function (Blueprint $table): void {
            $table->dropForeign('payroll_ibfk_1');
            $table->dropForeign('payroll_ibfk_2');
            $table->dropForeign('payroll_ibfk_3');
            $table->dropForeign('payroll_ibfk_4');
        });
        Schema::table('payroll_line_overrides', function (Blueprint $table): void {
            $table->dropForeign('fk_plo_created_by');
            $table->dropForeign('fk_plo_employee');
            $table->dropForeign('fk_plo_tenant');
        });
        Schema::table('payroll_statutory_settings', function (Blueprint $table): void {
            $table->dropForeign('fk_statutory_tenant');
        });
        Schema::table('performance_cycles', function (Blueprint $table): void {
            $table->dropForeign('performance_cycles_ibfk_1');
            $table->dropForeign('performance_cycles_ibfk_2');
        });
        Schema::table('performance_goals', function (Blueprint $table): void {
            $table->dropForeign('performance_goals_ibfk_1');
            $table->dropForeign('performance_goals_ibfk_2');
            $table->dropForeign('performance_goals_ibfk_3');
            $table->dropForeign('performance_goals_ibfk_4');
        });
        Schema::table('performance_reviews', function (Blueprint $table): void {
            $table->dropForeign('performance_reviews_ibfk_1');
            $table->dropForeign('performance_reviews_ibfk_2');
            $table->dropForeign('performance_reviews_ibfk_3');
            $table->dropForeign('performance_reviews_ibfk_4');
        });
        Schema::table('recurring_leaves', function (Blueprint $table): void {
            $table->dropForeign('recurring_leaves_ibfk_1');
            $table->dropForeign('recurring_leaves_ibfk_2');
        });
        Schema::table('required_document_categories', function (Blueprint $table): void {
            $table->dropForeign('required_document_categories_ibfk_1');
            $table->dropForeign('required_document_categories_ibfk_2');
            $table->dropForeign('required_document_categories_ibfk_3');
        });
        Schema::table('required_document_employees', function (Blueprint $table): void {
            $table->dropForeign('required_document_employees_ibfk_1');
            $table->dropForeign('required_document_employees_ibfk_2');
            $table->dropForeign('required_document_employees_ibfk_3');
        });
        Schema::table('required_documents', function (Blueprint $table): void {
            $table->dropForeign('required_documents_ibfk_1');
        });
        Schema::table('shifts', function (Blueprint $table): void {
            $table->dropForeign('shifts_ibfk_1');
            $table->dropForeign('shifts_ibfk_2');
        });
        Schema::table('station_recognition_logs', function (Blueprint $table): void {
            $table->dropForeign('srl_ibfk_station');
            $table->dropForeign('srl_ibfk_tenant');
        });
        Schema::table('super_admin_audit_log', function (Blueprint $table): void {
            $table->dropForeign('super_admin_audit_log_ibfk_1');
        });
        Schema::table('super_admin_devices', function (Blueprint $table): void {
            $table->dropForeign('fk_super_admin_devices_admin');
        });
        Schema::table('super_admin_sessions', function (Blueprint $table): void {
            $table->dropForeign('super_admin_sessions_ibfk_1');
        });
        Schema::table('support_messages', function (Blueprint $table): void {
            $table->dropForeign('support_messages_ibfk_1');
        });
        Schema::table('support_tickets', function (Blueprint $table): void {
            $table->dropForeign('support_tickets_ibfk_1');
            $table->dropForeign('support_tickets_ibfk_2');
        });
        Schema::table('warnings', function (Blueprint $table): void {
            $table->dropForeign('warnings_ibfk_1');
            $table->dropForeign('warnings_ibfk_2');
            $table->dropForeign('warnings_ibfk_3');
        });
    }
};
