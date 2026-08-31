<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('attendance', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('branch_id')->unsigned()->nullable();
            $table->integer('employee_id')->unsigned();
            $table->date('date');
            $table->time('check_in_time')->nullable();
            $table->time('check_out_time')->nullable();
            $table->decimal('check_in_latitude', 10, 7)->nullable();
            $table->decimal('check_in_longitude', 10, 7)->nullable();
            $table->integer('worked_minutes')->unsigned()->nullable()->default(0);
            $table->integer('overtime_minutes')->unsigned()->nullable()->default(0);
            $table->integer('late_minutes')->unsigned()->nullable()->default(0);
            $table->integer('early_leave_minutes')->unsigned()->nullable()->default(0);
            $table->enum('check_in_method', ['qr_gps', 'gps_only', 'qr_gps_face', 'face_selfie', 'wifi_gps', 'photo_gps', 'crew_gps', 'device', 'manual', 'kiosk', 'offline'])->nullable()->default('qr_gps');
            $table->enum('check_in_origin', ['app', 'web'])->nullable()->comment('Channel the check-in came from. NULL for pre-existing rows and for device/manual punches.');
            $table->enum('check_out_method', ['qr_gps', 'gps_only', 'qr_gps_face', 'face_selfie', 'wifi_gps', 'photo_gps', 'crew_gps', 'device', 'manual', 'kiosk', 'offline', 'auto'])->nullable();
            $table->enum('check_out_origin', ['app', 'web'])->nullable()->comment('Channel the check-out came from.');
            $table->enum('recognition_method', ['manual', 'qr_gps', 'mobile_face', 'device_fingerprint', 'device_face', 'device_card', 'device_password', 'station_face', 'station_fingerprint', 'station_both', 'station_qr', 'station_code'])->nullable();
            $table->decimal('recognition_confidence', 4, 3)->nullable();
            $table->integer('station_id')->unsigned()->nullable();
            $table->enum('status', ['present', 'absent', 'leave', 'holiday', 'weekly_off'])->default('present');
            $table->boolean('is_offline')->default(0);
            $table->boolean('is_vpn')->default(0)->comment('VPN detected on device at check-in (advisory)');
            $table->boolean('is_mock_location')->default(0)->comment('Mock-location flag reported by client (advisory)');
            $table->boolean('is_rooted_device')->default(0)->comment('Root/jailbreak flag reported by client (advisory)');
            $table->timestamp('synced_at')->nullable()->comment('When offline record was synced');
            $table->integer('recorded_by')->unsigned()->nullable()->comment('User who manually recorded this');
            $table->enum('deduction_mode', ['auto', 'days', 'amount'])->default('auto');
            $table->decimal('deduction_value', 10, 2)->nullable();
            $table->text('notes')->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->timestamp('updated_at')->nullable()->useCurrent()->useCurrentOnUpdate();
            $table->string('check_in_photo', 255)->nullable()->comment('Relative path under uploads/attendance/. Evidence for human review only — never scored or matched.');
            $table->string('check_out_photo', 255)->nullable();
            $table->boolean('shared_device_flag')->default(0)->comment('One browser recorded attendance for more than one employee today. Advisory — never blocks.');
            $table->char('kiosk_idempotency_key', 36)->nullable()->comment('Client-generated per punch so a retried kiosk request cannot double-insert');
            $table->char('kiosk_checkin_idem_key', 36)->nullable()->comment('Client-generated key for the check-in punch; a retry collides and replays');
            $table->char('kiosk_checkout_idem_key', 36)->nullable()->comment('Client-generated key for the check-out punch');
            $table->integer('recorded_by_employee_id')->unsigned()->nullable()->comment('employees.id of the supervisor who recorded this on site. Distinct from recorded_by, which is an administrator.');
            $table->string('crew_photo', 255)->nullable()->comment('Relative path under uploads/attendance/. One group photograph shared by every row in the batch. Evidence for a human — never scored, never matched.');
            $table->index(['branch_id', 'date'], 'idx_att_branch_date');
            $table->index(['recorded_by_employee_id'], 'idx_att_recorded_by_employee');
            $table->index(['status'], 'idx_att_status');
            $table->index(['tenant_id', 'date'], 'idx_att_tenant_date');
            $table->index(['recorded_by'], 'recorded_by');
            $table->unique(['kiosk_idempotency_key'], 'uniq_att_kiosk_idem');
            $table->unique(['kiosk_checkin_idem_key'], 'uniq_att_kiosk_idem_in');
            $table->unique(['kiosk_checkout_idem_key'], 'uniq_att_kiosk_idem_out');
            $table->unique(['employee_id', 'date'], 'uniq_attendance_emp_date');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('attendance');
    }
};
