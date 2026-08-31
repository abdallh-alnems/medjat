<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('super_admin_audit_log', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('admin_id')->unsigned()->nullable();
            $table->string('action', 100);
            $table->string('target_type', 50)->nullable();
            $table->string('target_id', 50)->nullable();
            $table->longText('payload')->nullable();
            $table->string('ip', 45)->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->index(['action'], 'idx_saalog_action');
            $table->index(['admin_id'], 'idx_saalog_admin');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('super_admin_audit_log');
    }
};
