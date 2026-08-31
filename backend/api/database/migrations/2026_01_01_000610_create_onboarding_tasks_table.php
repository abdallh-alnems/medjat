<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('onboarding_tasks', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('employee_id')->unsigned();
            $table->integer('template_id')->unsigned()->nullable()->comment('source template row, NULL for manually added');
            $table->string('title', 200);
            $table->enum('task_type', ['document', 'asset', 'account', 'generic'])->default('generic');
            $table->enum('status', ['pending', 'completed', 'skipped'])->default('pending');
            $table->integer('sort_order')->unsigned()->default(0);
            $table->integer('completed_by')->unsigned()->nullable();
            $table->timestamp('completed_at')->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->index(['tenant_id', 'employee_id', 'status'], 'idx_onbtask_tenant_emp');
            $table->index(['employee_id'], 'onboarding_tasks_ibfk_2');
            $table->index(['template_id'], 'onboarding_tasks_ibfk_3');
            $table->index(['completed_by'], 'onboarding_tasks_ibfk_4');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('onboarding_tasks');
    }
};
