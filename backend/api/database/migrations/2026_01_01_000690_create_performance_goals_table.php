<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('performance_goals', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('employee_id')->unsigned();
            $table->integer('cycle_id')->unsigned()->nullable()->comment('optional: link goal to a cycle');
            $table->string('title', 200);
            $table->text('description')->nullable();
            $table->string('metric', 150)->nullable()->comment('measurement unit / indicator, free text');
            $table->decimal('target_value', 14, 2)->nullable();
            $table->decimal('current_value', 14, 2)->default(0.00);
            $table->tinyInteger('weight')->unsigned()->default(0)->comment('goal weight % (0-100)');
            $table->tinyInteger('progress')->unsigned()->default(0)->comment('completion % 0-100');
            $table->enum('status', ['not_started', 'in_progress', 'completed', 'cancelled'])->default('not_started');
            $table->date('due_date')->nullable();
            $table->integer('created_by')->unsigned()->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->timestamp('updated_at')->nullable()->useCurrent()->useCurrentOnUpdate();
            $table->index(['cycle_id'], 'idx_pgoal_cycle');
            $table->index(['tenant_id', 'employee_id', 'status'], 'idx_pgoal_tenant_emp');
            $table->index(['employee_id'], 'performance_goals_ibfk_2');
            $table->index(['created_by'], 'performance_goals_ibfk_4');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('performance_goals');
    }
};
