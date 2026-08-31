<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('employee_suspensions', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('employee_id')->unsigned();
            $table->text('reason');
            $table->enum('pay_mode', ['unpaid', 'partial', 'full'])->default('unpaid');
            $table->decimal('pay_percentage', 5, 2)->nullable()->comment('Percent of salary paid during suspension when pay_mode=partial (0-100)');
            $table->date('start_date');
            $table->date('end_date')->nullable()->comment('NULL = open-ended until manually ended');
            $table->enum('status', ['active', 'ended'])->default('active');
            $table->string('previous_status', 32)->nullable()->comment('Employee status before suspension, restored on reactivation');
            $table->dateTime('ended_at')->nullable();
            $table->integer('ended_by')->unsigned()->nullable();
            $table->text('end_note')->nullable();
            $table->integer('created_by')->unsigned()->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->timestamp('updated_at')->nullable()->useCurrent()->useCurrentOnUpdate();
            $table->index(['created_by'], 'fk_susp_created_by');
            $table->index(['ended_by'], 'fk_susp_ended_by');
            $table->index(['employee_id', 'status'], 'idx_susp_active');
            $table->index(['employee_id', 'start_date', 'end_date'], 'idx_susp_dates');
            $table->index(['employee_id'], 'idx_susp_employee');
            $table->index(['status'], 'idx_susp_status');
            $table->index(['tenant_id'], 'idx_susp_tenant');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('employee_suspensions');
    }
};
