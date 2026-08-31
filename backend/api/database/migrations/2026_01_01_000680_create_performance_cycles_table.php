<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('performance_cycles', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->string('name', 150);
            $table->string('name_ar', 150)->nullable();
            $table->enum('period_type', ['monthly', 'quarterly', 'semi_annual', 'annual', 'custom'])->default('quarterly');
            $table->date('start_date');
            $table->date('end_date');
            $table->enum('status', ['draft', 'active', 'closed'])->default('draft');
            $table->integer('created_by')->unsigned()->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->timestamp('closed_at')->nullable();
            $table->index(['tenant_id', 'status'], 'idx_pcycle_tenant_status');
            $table->index(['created_by'], 'performance_cycles_ibfk_2');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('performance_cycles');
    }
};
