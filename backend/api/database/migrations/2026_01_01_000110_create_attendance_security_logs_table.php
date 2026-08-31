<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('attendance_security_logs', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('employee_id')->unsigned();
            $table->integer('branch_id')->unsigned()->nullable();
            $table->enum('reason', ['mock_location', 'rooted', 'jailbroken', 'vpn', 'gps_out_of_range', 'no_local_biometric', 'kiosk_ambiguous_match', 'kiosk_spoofing_suspected', 'kiosk_out_of_branch', 'kiosk_pin_bruteforce', 'kiosk_revoked_token', 'kiosk_version_blocked', 'web_not_permitted', 'web_pin_locked', 'web_shared_device', 'qr_replayed', 'qr_expired', 'crew_not_supervisor', 'replayed_embedding', 'web_wrong_network']);
            $table->enum('action', ['blocked', 'flagged'])->default('blocked');
            $table->decimal('latitude', 10, 7)->nullable();
            $table->decimal('longitude', 10, 7)->nullable();
            $table->string('ip_address', 45)->nullable();
            $table->string('platform', 20)->nullable()->comment('android | ios');
            $table->string('app_version', 20)->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->index(['employee_id'], 'idx_seclog_employee');
            $table->index(['tenant_id', 'created_at'], 'idx_seclog_tenant_date');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('attendance_security_logs');
    }
};
