<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('device_users', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned()->nullable();
            $table->integer('device_id')->unsigned();
            $table->string('device_user_id', 32)->comment('The PIN / User ID as stored on the device');
            $table->string('device_name', 100)->nullable()->comment('Name as typed into the device, shown to help HR match people');
            $table->integer('employee_id')->unsigned()->nullable();
            $table->string('card_number', 32)->nullable();
            $table->tinyInteger('privilege')->unsigned()->nullable()->comment('0 = user, 14 = device admin');
            $table->boolean('is_active')->default(1);
            $table->integer('linked_by')->unsigned()->nullable();
            $table->dateTime('linked_at')->nullable();
            $table->dateTime('last_punch_at')->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->timestamp('updated_at')->nullable()->useCurrent()->useCurrentOnUpdate();
            $table->index(['tenant_id', 'employee_id'], 'idx_device_user_employee');
            $table->index(['tenant_id', 'device_id', 'employee_id'], 'idx_device_user_pending');
            $table->unique(['device_id', 'device_user_id'], 'uniq_device_user');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('device_users');
    }
};
