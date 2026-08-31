<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('open_shift_claims', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('open_shift_id')->unsigned();
            $table->integer('employee_id')->unsigned();
            $table->enum('status', ['pending', 'approved', 'rejected', 'withdrawn'])->default('pending');
            $table->integer('decided_by')->unsigned()->nullable();
            $table->timestamp('decided_at')->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->index(['employee_id'], 'idx_claim_employee');
            $table->index(['tenant_id', 'status'], 'idx_claim_tenant_status');
            $table->index(['decided_by'], 'open_shift_claims_ibfk_4');
            $table->unique(['open_shift_id', 'employee_id'], 'uniq_claim_shift_emp');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('open_shift_claims');
    }
};
