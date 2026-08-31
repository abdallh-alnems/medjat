<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('payroll_line_overrides', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('employee_id')->unsigned();
            $table->char('month', 7)->comment('YYYY-MM');
            $table->enum('line_kind', ['deduction', 'bonus']);
            $table->string('line_type', 40);
            $table->string('line_date', 20)->nullable();
            $table->text('line_desc')->nullable();
            $table->char('line_hash', 40)->comment('sha1(type|date|desc)');
            $table->boolean('waived')->default(0)->comment('1 = line removed for this month');
            $table->decimal('override_amount', 12, 2)->nullable()->comment('replacement amount when not waived');
            $table->text('reason')->nullable();
            $table->integer('created_by')->unsigned()->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->timestamp('updated_at')->nullable()->useCurrent()->useCurrentOnUpdate();
            $table->index(['created_by'], 'fk_plo_created_by');
            $table->index(['employee_id', 'month', 'tenant_id'], 'idx_plo_emp_month');
            $table->unique(['tenant_id', 'employee_id', 'month', 'line_kind', 'line_hash'], 'uq_override');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('payroll_line_overrides');
    }
};
