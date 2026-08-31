<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('loan_installments', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('loan_id')->unsigned();
            $table->integer('employee_id')->unsigned();
            $table->string('month', 7)->comment('YYYY-MM');
            $table->integer('seq')->unsigned()->default(1);
            $table->decimal('amount', 12, 2);
            $table->enum('status', ['pending', 'paid'])->default('pending');
            $table->timestamp('paid_at')->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->index(['employee_id', 'month', 'status'], 'idx_inst_emp_month');
            $table->index(['tenant_id'], 'idx_inst_tenant');
            $table->unique(['loan_id', 'month'], 'uniq_loan_month');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('loan_installments');
    }
};
