<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('manager_invitations', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->string('email', 150);
            $table->string('name', 100);
            $table->enum('role', ['general_manager', 'hr', 'branch_manager', 'attendance', 'viewer']);
            $table->integer('branch_id')->unsigned()->nullable()->comment('Scope: null = all branches');
            $table->longText('permissions')->nullable();
            $table->string('token_hash', 64)->comment('SHA-256 of invite token');
            $table->timestamp('expires_at')->comment('72 hours from creation');
            $table->timestamp('accepted_at')->nullable();
            $table->integer('accepted_admin_id')->unsigned()->nullable();
            $table->timestamp('cancelled_at')->nullable();
            $table->integer('invited_by')->unsigned()->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->timestamp('updated_at')->nullable()->useCurrent()->useCurrentOnUpdate();
            $table->index(['accepted_admin_id'], 'accepted_user_id');
            $table->index(['branch_id'], 'branch_id');
            $table->index(['email'], 'idx_invite_email');
            $table->index(['expires_at'], 'idx_invite_expires');
            $table->index(['tenant_id'], 'idx_invite_tenant');
            $table->index(['invited_by'], 'invited_by');
            $table->unique(['token_hash'], 'token_hash');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('manager_invitations');
    }
};
