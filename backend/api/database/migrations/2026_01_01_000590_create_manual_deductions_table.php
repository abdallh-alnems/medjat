<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('manual_deductions', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('employee_id')->unsigned();
            $table->integer('batch_id')->unsigned()->nullable();
            $table->decimal('amount', 12, 2);
            $table->text('reason');
            $table->string('month', 7)->comment('YYYY-MM');
            $table->integer('created_by')->unsigned()->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->index(['created_by'], 'created_by');
            $table->index(['batch_id'], 'idx_md_batch');
            $table->index(['employee_id', 'month'], 'idx_md_emp_month');
            $table->index(['tenant_id', 'month'], 'idx_md_tenant_month');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('manual_deductions');
    }
};
