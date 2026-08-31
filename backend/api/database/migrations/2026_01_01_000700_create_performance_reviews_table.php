<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('performance_reviews', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('employee_id')->unsigned();
            $table->integer('cycle_id')->unsigned()->nullable();
            $table->integer('reviewer_id')->unsigned()->nullable()->comment('admins.id — who entered/conducted the review');
            $table->enum('reviewer_type', ['manager', 'self', 'peer', 'subordinate'])->default('manager')->comment('foundation for 360°');
            $table->decimal('rating', 3, 2)->nullable()->comment('rating 0.00 - 5.00');
            $table->text('strengths')->nullable();
            $table->text('areas_for_improvement')->nullable();
            $table->text('review')->nullable()->comment('general notes (backward-compatible column)');
            $table->enum('status', ['draft', 'submitted'])->default('submitted');
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->timestamp('updated_at')->nullable()->useCurrent()->useCurrentOnUpdate();
            $table->index(['cycle_id'], 'idx_prev_cycle');
            $table->index(['tenant_id', 'employee_id'], 'idx_prev_tenant_emp');
            $table->index(['employee_id'], 'performance_reviews_ibfk_2');
            $table->index(['reviewer_id'], 'performance_reviews_ibfk_4');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('performance_reviews');
    }
};
