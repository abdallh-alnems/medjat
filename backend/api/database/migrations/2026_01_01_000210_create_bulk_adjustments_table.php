<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('bulk_adjustments', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->enum('kind', ['bonus', 'deduction']);
            $table->enum('scope_type', ['all', 'branch', 'category', 'employee', 'shift']);
            $table->integer('scope_id')->unsigned()->nullable()->comment('NULL for scope_type = all');
            $table->string('scope_name', 190)->nullable()->comment('snapshot label for display');
            $table->decimal('amount', 12, 2)->comment('fixed money OR percent value (0-100)');
            $table->enum('amount_type', ['fixed', 'percent'])->default('fixed');
            $table->text('reason');
            $table->string('month', 7)->comment('YYYY-MM');
            $table->integer('created_by')->unsigned()->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->index(['created_by'], 'created_by');
            $table->index(['tenant_id', 'month'], 'idx_ba_tenant_month');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('bulk_adjustments');
    }
};
