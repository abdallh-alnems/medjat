<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('leaves', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('employee_id')->unsigned();
            $table->date('date');
            $table->date('start_date');
            $table->date('end_date');
            $table->enum('type', ['annual', 'sick', 'personal', 'unpaid', 'weekly_off', 'converted_from_absence'])->default('annual');
            $table->text('reason')->nullable();
            $table->enum('status', ['pending', 'approved', 'rejected'])->default('pending');
            $table->integer('approved_by')->unsigned()->nullable();
            $table->timestamp('approved_at')->nullable();
            $table->integer('rejected_by')->unsigned()->nullable();
            $table->text('rejection_reason')->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->timestamp('updated_at')->nullable()->useCurrent()->useCurrentOnUpdate();
            $table->index(['approved_by'], 'approved_by');
            $table->index(['employee_id', 'date'], 'idx_leave_emp_date');
            $table->index(['status'], 'idx_leave_status');
            $table->index(['tenant_id'], 'idx_leave_tenant');
            $table->index(['rejected_by'], 'rejected_by');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('leaves');
    }
};
