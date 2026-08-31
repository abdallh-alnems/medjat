<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('employees', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('branch_id')->unsigned()->nullable();
            $table->longText('attendance_methods')->nullable()->comment('NULL = inherit (category/branch/tenant); array = employee override');
            $table->integer('admin_id')->unsigned()->nullable();
            $table->string('employee_code', 30)->nullable()->comment('Internal staff number');
            $table->string('name', 100);
            $table->string('phone', 20)->nullable();
            $table->string('job_title', 100)->nullable();
            $table->string('department', 100)->nullable();
            $table->string('national_id', 20)->nullable();
            $table->string('nationality', 60)->nullable();
            $table->string('iqama_number', 30)->nullable()->comment('Residency / iqama number');
            $table->date('iqama_expiry')->nullable();
            $table->string('passport_number', 30)->nullable();
            $table->date('passport_expiry')->nullable();
            $table->string('work_permit_number', 40)->nullable()->comment('Work permit / labor card');
            $table->date('work_permit_expiry')->nullable();
            $table->enum('contract_type', ['permanent', 'fixed_term', 'part_time', 'temporary'])->nullable();
            $table->date('contract_start')->nullable();
            $table->date('contract_end')->nullable();
            $table->date('health_insurance_expiry')->nullable();
            $table->decimal('base_salary', 12, 2)->unsigned()->default(0.00);
            $table->date('hire_date')->nullable();
            $table->time('work_start_time')->default('09:00:00');
            $table->time('work_end_time')->default('17:00:00');
            $table->integer('annual_leave_days')->nullable()->comment('NULL = inherit tenant default; number = per-employee override');
            $table->set('weekly_off_days', ['saturday', 'sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday'])->nullable();
            $table->date('auto_terminate_at')->nullable()->comment('Auto-terminate the employee on this date (fixed-term workers); NULL = open-ended');
            $table->date('terminated_at')->nullable()->comment('تاريخ إنهاء الخدمة — يُستخدم لحساب الدوران والقوى العاملة');
            $table->integer('shift_id')->unsigned()->nullable();
            $table->enum('shift_type', ['fixed', 'rotating'])->default('fixed');
            $table->enum('status', ['pending_activation', 'active', 'terminated', 'on_leave', 'suspended'])->default('pending_activation');
            $table->string('profile_image', 500)->nullable();
            $table->binary('face_embedding')->nullable()->comment('For ML Kit face verification (v2)');
            $table->string('face_photo_url', 500)->nullable();
            $table->string('face_model_version', 40)->nullable()->comment('Embedding model that produced face_embedding (e.g. mobilefacenet_v1)');
            $table->smallInteger('face_embedding_dim')->unsigned()->nullable()->comment('Number of dimensions in face_embedding');
            $table->string('bank_name', 100)->nullable();
            $table->string('bank_account_number', 34)->nullable();
            $table->string('bank_iban', 34)->nullable();
            $table->string('bank_swift', 11)->nullable();
            $table->dateTime('face_enrolled_at')->nullable();
            $table->decimal('face_quality_score', 4, 3)->nullable();
            $table->dateTime('fingerprint_enrolled_at')->nullable();
            $table->enum('biometric_enrollment_status', ['not_enrolled', 'face_only', 'fingerprint_only', 'both'])->nullable()->default('not_enrolled');
            $table->boolean('has_linked_account')->nullable()->default(0);
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->timestamp('updated_at')->nullable()->useCurrent()->useCurrentOnUpdate();
            $table->string('kiosk_pin_hash', 255)->nullable()->comment('Per-employee kiosk fallback code, hashed; plaintext shown once at issue');
            $table->dateTime('kiosk_pin_set_at')->nullable();
            $table->integer('face_enrolled_by_station_id')->unsigned()->nullable()->comment('Which kiosk performed the enrollment, if any — provenance for an enrollment nobody watched');
            $table->integer('crew_supervisor_id')->unsigned()->nullable()->comment('employees.id of the supervisor who may record this person attendance on site. NULL = nobody.');
            $table->index(['admin_id'], 'idx_emp_admin');
            $table->index(['tenant_id', 'status', 'auto_terminate_at'], 'idx_emp_auto_terminate');
            $table->index(['branch_id'], 'idx_emp_branch');
            $table->index(['tenant_id', 'contract_end'], 'idx_emp_contract_end');
            $table->index(['crew_supervisor_id', 'tenant_id'], 'idx_emp_crew_supervisor');
            $table->index(['tenant_id', 'health_insurance_expiry'], 'idx_emp_health_expiry');
            $table->index(['tenant_id', 'iqama_expiry'], 'idx_emp_iqama_expiry');
            $table->index(['tenant_id', 'passport_expiry'], 'idx_emp_passport_expiry');
            $table->index(['shift_id'], 'idx_emp_shift');
            $table->index(['status'], 'idx_emp_status');
            $table->index(['tenant_id'], 'idx_emp_tenant');
            $table->index(['tenant_id', 'terminated_at'], 'idx_emp_terminated_at');
            $table->index(['tenant_id', 'work_permit_expiry'], 'idx_emp_workpermit_expiry');
            $table->unique(['tenant_id', 'phone'], 'uniq_emp_phone_tenant');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('employees');
    }
};
