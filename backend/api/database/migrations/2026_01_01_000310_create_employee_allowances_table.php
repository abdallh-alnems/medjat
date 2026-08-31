<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('employee_allowances', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('employee_id')->unsigned();
            $table->string('type', 40)->comment('housing|transport|food|communication|other (or custom key)');
            $table->string('label', 120)->nullable()->comment('Optional human label, overrides the type translation in slips');
            $table->decimal('amount', 12, 2);
            $table->string('start_month', 7)->comment('YYYY-MM inclusive');
            $table->string('end_month', 7)->nullable()->comment('YYYY-MM inclusive; NULL = ongoing');
            $table->integer('created_by')->unsigned()->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->timestamp('updated_at')->nullable()->useCurrent()->useCurrentOnUpdate();
            $table->index(['created_by'], 'created_by');
            $table->index(['employee_id', 'tenant_id'], 'idx_alw_emp');
            $table->index(['tenant_id', 'start_month', 'end_month'], 'idx_alw_tenant_active');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('employee_allowances');
    }
};
