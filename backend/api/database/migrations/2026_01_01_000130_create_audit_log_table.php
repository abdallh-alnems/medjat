<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('audit_log', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('admin_id')->unsigned()->nullable();
            $table->string('action', 100);
            $table->string('target_type', 50)->nullable();
            $table->string('target_id', 50)->nullable();
            $table->longText('payload')->nullable();
            $table->string('ip', 45)->nullable();
            $table->string('user_agent', 255)->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->index(['action'], 'idx_audit_action');
            $table->index(['admin_id'], 'idx_audit_admin');
            $table->index(['target_type', 'target_id'], 'idx_audit_target');
            $table->index(['tenant_id'], 'idx_audit_tenant');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('audit_log');
    }
};
