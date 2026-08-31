<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('support_tickets', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('opened_by_admin_id')->unsigned()->comment('admins.id who opened it');
            $table->string('subject', 255);
            $table->enum('category', ['technical', 'billing', 'feature_request', 'account', 'other'])->default('other');
            $table->enum('priority', ['low', 'normal', 'high', 'urgent'])->default('normal');
            $table->enum('status', ['open', 'pending_support', 'pending_user', 'resolved', 'closed'])->default('open');
            $table->integer('assigned_super_admin_id')->unsigned()->nullable()->comment('super_admins.id handling it');
            $table->timestamp('last_message_at')->nullable();
            $table->string('last_message_preview', 255)->nullable();
            $table->boolean('unread_for_user')->default(0)->comment('1 = support reply unread by user');
            $table->boolean('unread_for_support')->default(1)->comment('1 = user message unread by support');
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->timestamp('updated_at')->nullable()->useCurrent()->useCurrentOnUpdate();
            $table->index(['opened_by_admin_id'], 'idx_support_tickets_opened_by');
            $table->index(['status', 'last_message_at'], 'idx_support_tickets_status');
            $table->index(['tenant_id', 'status'], 'idx_support_tickets_tenant');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('support_tickets');
    }
};
