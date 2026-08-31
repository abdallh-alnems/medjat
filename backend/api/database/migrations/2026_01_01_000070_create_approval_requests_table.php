<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('approval_requests', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('chain_id')->unsigned()->nullable()->comment('Referential; SET NULL if chain deleted (steps are snapshot)');
            $table->string('entity_type', 40);
            $table->integer('entity_id')->unsigned();
            $table->integer('requested_by_admin_id')->unsigned()->nullable();
            $table->integer('requested_by_employee_id')->unsigned()->nullable();
            $table->decimal('context_amount', 14, 2)->nullable()->comment('Amount used for conditional matching (audit)');
            $table->tinyInteger('current_step')->unsigned()->default(1);
            $table->tinyInteger('total_steps')->unsigned();
            $table->enum('status', ['pending', 'approved', 'rejected', 'cancelled'])->default('pending');
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->timestamp('decided_at')->nullable()->comment('Final decision timestamp');
            $table->index(['chain_id'], 'approval_requests_ibfk_2');
            $table->index(['tenant_id', 'entity_type', 'entity_id'], 'idx_req_entity');
            $table->index(['tenant_id', 'status'], 'idx_req_tenant_status');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('approval_requests');
    }
};
