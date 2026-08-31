<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('required_document_employees', function (Blueprint $table): void {
            $table->integer('required_document_id')->unsigned();
            $table->integer('employee_id')->unsigned();
            $table->integer('tenant_id')->unsigned();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->index(['employee_id', 'tenant_id'], 'idx_rde_employee');
            $table->index(['tenant_id'], 'idx_rde_tenant');
            $table->primary(['required_document_id', 'employee_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('required_document_employees');
    }
};
