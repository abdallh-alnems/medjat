<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('approval_chain_steps', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('chain_id')->unsigned();
            $table->tinyInteger('step_order')->unsigned()->comment('Starts at 1, sequential');
            $table->enum('approver_type', ['role', 'admin'])->default('role');
            $table->string('approver_role', 40)->nullable()->comment('When approver_type=role');
            $table->integer('approver_admin_id')->unsigned()->nullable()->comment('When approver_type=admin');
            $table->string('label', 120)->nullable()->comment('Descriptive name for the step');
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->index(['approver_admin_id'], 'idx_step_admin');
            $table->index(['tenant_id'], 'idx_step_tenant');
            $table->unique(['chain_id', 'step_order'], 'uniq_chain_step_order');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('approval_chain_steps');
    }
};
