<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('warnings', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('employee_id')->unsigned();
            $table->enum('type', ['verbal', 'written', 'final', 'device_change', 'system'])->default('verbal');
            $table->text('reason');
            $table->integer('issued_by')->unsigned()->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->index(['employee_id'], 'idx_warn_emp');
            $table->index(['tenant_id'], 'idx_warn_tenant');
            $table->index(['issued_by'], 'issued_by');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('warnings');
    }
};
