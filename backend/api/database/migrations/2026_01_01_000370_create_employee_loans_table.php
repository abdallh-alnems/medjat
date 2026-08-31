<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('employee_loans', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('employee_id')->unsigned();
            $table->enum('type', ['loan', 'advance'])->default('loan');
            $table->decimal('total_amount', 12, 2);
            $table->decimal('installment_amount', 12, 2);
            $table->integer('installments_count')->unsigned()->default(1);
            $table->integer('installments_paid')->unsigned()->default(0);
            $table->string('start_month', 7)->comment('YYYY-MM');
            $table->text('reason')->nullable();
            $table->enum('status', ['pending', 'active', 'completed', 'cancelled', 'rejected'])->default('pending');
            $table->integer('created_by')->unsigned()->nullable();
            $table->integer('approved_by')->unsigned()->nullable();
            $table->timestamp('approved_at')->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->index(['approved_by'], 'approved_by');
            $table->index(['created_by'], 'created_by');
            $table->index(['employee_id'], 'idx_loan_employee');
            $table->index(['tenant_id', 'status'], 'idx_loan_tenant_status');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('employee_loans');
    }
};
