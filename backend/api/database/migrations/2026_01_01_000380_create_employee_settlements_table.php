<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('employee_settlements', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('employee_id')->unsigned();
            $table->enum('reason', ['resignation', 'termination', 'end_of_contract', 'retirement', 'death', 'absconding', 'other'])->default('resignation');
            $table->text('notes')->nullable();
            $table->date('last_working_day');
            $table->date('hire_date')->nullable()->comment('Snapshot of service-start date used for the gratuity calc');
            $table->decimal('base_salary', 12, 2)->default(0.00);
            $table->decimal('daily_rate', 12, 2)->default(0.00)->comment('base_salary / 30');
            $table->decimal('years_of_service', 6, 2)->default(0.00);
            $table->decimal('pending_salary', 12, 2)->default(0.00);
            $table->decimal('gratuity_days', 7, 2)->default(0.00);
            $table->decimal('gratuity_amount', 12, 2)->default(0.00);
            $table->decimal('leave_balance_days', 7, 2)->default(0.00);
            $table->decimal('leave_encashment', 12, 2)->default(0.00);
            $table->decimal('other_additions', 12, 2)->default(0.00);
            $table->decimal('outstanding_loans', 12, 2)->default(0.00);
            $table->decimal('other_deductions', 12, 2)->default(0.00);
            $table->decimal('total_earnings', 12, 2)->default(0.00);
            $table->decimal('total_deductions', 12, 2)->default(0.00);
            $table->decimal('net_amount', 12, 2)->default(0.00);
            $table->longText('line_items')->nullable()->comment('Custom editable rows [{label,kind,amount}]');
            $table->longText('breakdown')->nullable()->comment('Frozen computed snapshot captured at approval');
            $table->enum('status', ['draft', 'approved', 'paid'])->default('draft');
            $table->integer('created_by')->unsigned()->nullable();
            $table->integer('approved_by')->unsigned()->nullable();
            $table->dateTime('approved_at')->nullable();
            $table->dateTime('paid_at')->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->timestamp('updated_at')->nullable()->useCurrent()->useCurrentOnUpdate();
            $table->index(['approved_by'], 'fk_settlement_approved_by');
            $table->index(['created_by'], 'fk_settlement_created_by');
            $table->index(['employee_id'], 'fk_settlement_employee');
            $table->index(['tenant_id', 'status'], 'idx_settlement_status');
            $table->index(['tenant_id'], 'idx_settlement_tenant');
            $table->unique(['tenant_id', 'employee_id'], 'uniq_settlement_employee');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('employee_settlements');
    }
};
