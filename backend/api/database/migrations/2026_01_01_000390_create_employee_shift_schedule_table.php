<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('employee_shift_schedule', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('employee_id')->unsigned();
            $table->integer('shift_id')->unsigned()->nullable()->comment('NULL = rest / off day');
            $table->date('work_date');
            $table->enum('status', ['draft', 'published'])->default('draft');
            $table->integer('created_by')->unsigned()->nullable()->comment('admin who last set this cell');
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->timestamp('updated_at')->nullable()->useCurrent()->useCurrentOnUpdate();
            $table->index(['created_by'], 'fk_sched_admin');
            $table->index(['shift_id'], 'idx_sched_shift');
            $table->index(['tenant_id', 'work_date'], 'idx_sched_tenant_date');
            $table->unique(['employee_id', 'work_date'], 'uniq_sched_emp_date');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('employee_shift_schedule');
    }
};
