<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('device_commands', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('device_id')->unsigned();
            $table->string('kind', 32)->comment('sync_time, reboot, info, delete_user');
            $table->text('payload')->nullable()->comment('The literal command line sent to the device');
            $table->enum('state', ['queued', 'sent', 'done', 'failed'])->default('queued');
            $table->string('result_code', 16)->nullable();
            $table->dateTime('sent_at')->nullable();
            $table->dateTime('completed_at')->nullable();
            $table->integer('created_by')->unsigned()->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->index(['device_id', 'state', 'id'], 'idx_command_queue');
            $table->index(['tenant_id', 'created_at'], 'idx_command_tenant');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('device_commands');
    }
};
