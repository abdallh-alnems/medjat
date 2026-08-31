<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('approval_request_steps', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('request_id')->unsigned();
            $table->tinyInteger('step_order')->unsigned();
            $table->enum('approver_type', ['role', 'admin']);
            $table->string('approver_role', 40)->nullable();
            $table->integer('approver_admin_id')->unsigned()->nullable();
            $table->string('label', 120)->nullable();
            $table->enum('status', ['pending', 'approved', 'rejected', 'skipped'])->default('pending');
            $table->integer('decided_by')->unsigned()->nullable()->comment('admins.id who decided this step');
            $table->timestamp('decided_at')->nullable();
            $table->string('note', 255)->nullable();
            $table->index(['approver_admin_id'], 'idx_reqstep_admin');
            $table->index(['tenant_id', 'status'], 'idx_reqstep_tenant_status');
            $table->unique(['request_id', 'step_order'], 'uniq_reqstep_order');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('approval_request_steps');
    }
};
