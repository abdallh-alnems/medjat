<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('attendance_stations', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('branch_id')->unsigned();
            $table->string('name', 100)->nullable()->comment('Set at pairing, e.g. "Main gate"');
            $table->enum('status', ['active', 'revoked'])->default('active')->comment('Revocation is a state, never a delete: attendance.station_id must not be orphaned');
            $table->string('device_model', 100)->nullable();
            $table->string('platform', 20)->default('android')->comment('Reserved for a future iPad build; Android only for now');
            $table->string('app_version', 20)->nullable()->comment('Reported on every heartbeat; drives the minimum-version gate');
            $table->dateTime('last_seen_at')->nullable()->comment('Stale during working hours = a dark kiosk, which management is alerted about');
            $table->string('last_ip', 45)->nullable();
            $table->dateTime('last_punch_at')->nullable();
            $table->integer('punch_count')->unsigned()->default(0);
            $table->integer('paired_by')->unsigned()->nullable()->comment('admins.id of the administrator who paired this tablet');
            $table->dateTime('paired_at')->nullable();
            $table->integer('revoked_by')->unsigned()->nullable()->comment('admins.id of the administrator who revoked it');
            $table->dateTime('revoked_at')->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->timestamp('updated_at')->nullable()->useCurrent()->useCurrentOnUpdate();
            $table->string('admin_session_hash', 64)->nullable()->comment('SHA-256 of the open administration session token; NULL when closed');
            $table->dateTime('admin_session_expires_at')->nullable()->comment('Computed in SQL. Refreshed by activity so a long enrollment run is not interrupted');
            $table->integer('admin_session_by')->unsigned()->nullable()->comment('admins.id who authorised the open session — carried onto every enrollment made during it');
            $table->index(['branch_id', 'status'], 'idx_station_branch');
            $table->index(['last_seen_at'], 'idx_station_last_seen');
            $table->index(['tenant_id', 'status'], 'idx_station_tenant');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('attendance_stations');
    }
};
