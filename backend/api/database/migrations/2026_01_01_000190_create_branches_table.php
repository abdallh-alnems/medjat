<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('branches', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->string('name', 100);
            $table->text('address')->nullable();
            $table->decimal('latitude', 10, 7)->default(0.0000000);
            $table->decimal('longitude', 10, 7)->default(0.0000000);
            $table->string('qr_code', 50)->nullable();
            $table->boolean('is_active')->default(1);
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->timestamp('updated_at')->nullable()->useCurrent()->useCurrentOnUpdate();
            $table->longText('attendance_methods')->nullable()->comment('Branch override; NULL inherits tenants.attendance_methods');
            $table->integer('gps_radius_meters')->unsigned()->default(100)->comment('Allowed GPS radius for check-in in meters');
            $table->tinyInteger('cycle_start_day')->unsigned()->nullable()->comment('Per-branch override of attendance cycle start day; NULL = inherit company');
            $table->boolean('station_enabled')->default(0);
            $table->enum('station_methods', ['face_only', 'fingerprint_only', 'both_available'])->nullable()->default('face_only');
            $table->integer('station_gps_radius_meters')->nullable()->default(30);
            $table->decimal('station_confidence_threshold', 3, 2)->nullable()->default(0.85);
            $table->string('station_admin_pin_hash', 255)->nullable();
            $table->boolean('station_anti_spoofing_enabled')->default(1);
            $table->boolean('allow_offline_attendance')->nullable()->comment('NULL = inherit tenant; 1 = forced on; 0 = forced off');
            $table->decimal('face_match_threshold', 4, 3)->nullable();
            $table->boolean('face_liveness_required')->nullable();
            $table->enum('wifi_mode', ['learning', 'enforcing', 'optional'])->nullable()->comment('learning = record only; enforcing = reject unknown networks; optional = GPS or WiFi');
            $table->enum('wifi_match', ['bssid', 'ip', 'either'])->default('bssid')->comment('bssid = access point MAC; ip = public egress IP (works on iOS without entitlement)');
            $table->decimal('station_match_threshold', 4, 3)->nullable()->comment('Kiosk 1:N absolute threshold; NULL = system default. Stricter than 1:1 selfie matching');
            $table->decimal('station_match_margin', 4, 3)->nullable()->comment('Required gap between best and runner-up candidate; NULL = system default. This is what makes 1:N safe');
            $table->boolean('station_code_fallback_enabled')->default(1)->comment('Whether the per-employee code path is offered at this branch kiosks');
            $table->boolean('rotating_qr_enabled')->default(0)->comment('Require a time-limited code from a branch display instead of the printed branches.qr_code.');
            $table->index(['tenant_id'], 'idx_branch_tenant');
            $table->unique(['qr_code'], 'qr_code');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('branches');
    }
};
