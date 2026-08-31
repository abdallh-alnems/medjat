<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('payroll', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('employee_id')->unsigned();
            $table->integer('branch_id')->unsigned()->nullable();
            $table->string('month', 7)->comment('YYYY-MM');
            $table->decimal('base_salary', 12, 2)->default(0.00);
            $table->decimal('total_deductions', 12, 2)->default(0.00);
            $table->decimal('total_bonuses', 12, 2)->default(0.00);
            $table->decimal('net_salary', 12, 2)->default(0.00);
            $table->integer('working_days')->unsigned()->default(0);
            $table->integer('present_days')->unsigned()->default(0);
            $table->integer('absent_days')->unsigned()->default(0);
            $table->integer('overtime_total_minutes')->unsigned()->default(0);
            $table->longText('breakdown')->nullable();
            $table->enum('status', ['draft', 'approved', 'paid'])->default('draft');
            $table->integer('approved_by')->unsigned()->nullable();
            $table->timestamp('approved_at')->nullable();
            $table->timestamp('paid_at')->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->timestamp('updated_at')->nullable()->useCurrent()->useCurrentOnUpdate();
            $table->index(['approved_by'], 'approved_by');
            $table->index(['branch_id'], 'branch_id');
            $table->index(['status'], 'idx_payroll_status');
            $table->index(['tenant_id', 'month'], 'idx_payroll_tenant_month');
            $table->unique(['employee_id', 'month'], 'uniq_payroll_emp_month');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('payroll');
    }
};
