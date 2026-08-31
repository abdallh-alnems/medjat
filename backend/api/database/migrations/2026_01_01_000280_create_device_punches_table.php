<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('device_punches', function (Blueprint $table): void {
            $table->bigIncrements('id');
            $table->integer('tenant_id')->unsigned()->nullable();
            $table->integer('device_id')->unsigned();
            $table->string('device_user_id', 32);
            $table->integer('employee_id')->unsigned()->nullable();
            $table->dateTime('punched_at')->comment('Company local time (device wall clock + clock_offset_minutes)');
            $table->tinyInteger('status_code')->unsigned()->nullable()->comment('0 in, 1 out, 2/3 break, 4/5 overtime');
            $table->tinyInteger('verify_mode')->unsigned()->nullable()->comment('1 fingerprint, 4 card, 15 face, 0 password');
            $table->string('work_code', 16)->nullable();
            $table->enum('direction', ['in', 'out'])->nullable();
            $table->enum('state', ['applied', 'duplicate', 'unmatched', 'ignored', 'failed'])->default('unmatched');
            $table->string('note', 191)->nullable();
            $table->integer('attendance_id')->unsigned()->nullable();
            $table->string('raw_line', 255)->nullable();
            $table->timestamp('received_at')->nullable()->useCurrent();
            $table->index(['tenant_id', 'employee_id', 'punched_at'], 'idx_punch_employee');
            $table->index(['device_id', 'state', 'punched_at'], 'idx_punch_state');
            $table->index(['tenant_id', 'punched_at'], 'idx_punch_tenant_time');
            $table->unique(['device_id', 'device_user_id', 'punched_at'], 'uniq_device_punch');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('device_punches');
    }
};
