<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('attendance_devices', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned()->nullable();
            $table->integer('branch_id')->unsigned()->nullable();
            $table->string('serial_number', 64)->comment('SN as reported by the device, upper-cased');
            $table->string('name', 100)->nullable();
            $table->enum('vendor', ['zkteco', 'hikvision', 'other'])->default('zkteco');
            $table->string('model', 80)->nullable();
            $table->string('firmware', 80)->nullable();
            $table->enum('status', ['unclaimed', 'active', 'disabled'])->default('unclaimed');
            $table->enum('direction_mode', ['auto', 'device_status'])->default('auto');
            $table->smallInteger('min_interval_seconds')->unsigned()->default(60);
            $table->smallInteger('clock_offset_minutes')->default(0);
            $table->boolean('keep_unmatched')->default(1);
            $table->boolean('debug_logging')->default(0);
            $table->dateTime('last_seen_at')->nullable();
            $table->string('last_ip', 45)->nullable();
            $table->dateTime('last_punch_at')->nullable();
            $table->smallInteger('user_count')->unsigned()->nullable()->comment('As last reported by the device');
            $table->integer('claimed_by')->unsigned()->nullable();
            $table->dateTime('claimed_at')->nullable();
            $table->dateTime('first_seen_at')->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->timestamp('updated_at')->nullable()->useCurrent()->useCurrentOnUpdate();
            $table->index(['tenant_id', 'branch_id'], 'idx_device_branch');
            $table->index(['tenant_id', 'status'], 'idx_device_tenant');
            $table->unique(['serial_number'], 'uniq_device_serial');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('attendance_devices');
    }
};
