<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('recurring_leaves', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('branch_id')->unsigned()->nullable();
            $table->enum('day_of_week', ['saturday', 'sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday']);
            $table->string('type', 50)->default('weekly_off');
            $table->text('reason')->nullable();
            $table->boolean('is_active')->default(1);
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->index(['branch_id'], 'branch_id');
            $table->index(['tenant_id'], 'idx_recleave_tenant');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('recurring_leaves');
    }
};
