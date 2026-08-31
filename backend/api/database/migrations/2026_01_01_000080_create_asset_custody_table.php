<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('asset_custody', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('employee_id')->unsigned();
            $table->enum('type', ['money', 'equipment', 'device', 'vehicle', 'document', 'other'])->default('equipment');
            $table->string('name', 255);
            $table->text('description')->nullable();
            $table->decimal('value', 12, 2)->nullable();
            $table->string('currency', 8)->default('SAR');
            $table->string('serial_no', 128)->nullable();
            $table->integer('quantity')->unsigned()->default(1);
            $table->string('assign_photo_url', 512)->nullable();
            $table->string('return_photo_url', 512)->nullable();
            $table->enum('status', ['assigned', 'return_requested', 'returned'])->default('assigned');
            $table->text('notes')->nullable();
            $table->text('return_note')->nullable();
            $table->text('rejection_reason')->nullable();
            $table->date('assigned_at');
            $table->integer('assigned_by')->unsigned()->nullable();
            $table->timestamp('return_requested_at')->nullable();
            $table->timestamp('returned_at')->nullable();
            $table->integer('return_approved_by')->unsigned()->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->index(['assigned_by'], 'assigned_by');
            $table->index(['employee_id'], 'idx_asset_employee');
            $table->index(['tenant_id', 'status'], 'idx_asset_tenant_status');
            $table->index(['return_approved_by'], 'return_approved_by');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('asset_custody');
    }
};
