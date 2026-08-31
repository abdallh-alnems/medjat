<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('login_attempts', function (Blueprint $table): void {
            $table->increments('id');
            $table->string('identifier', 255)->comment('Email / phone / ip');
            $table->enum('identifier_type', ['email', 'phone', 'ip', 'employee_code']);
            $table->integer('tenant_id')->unsigned()->nullable();
            $table->integer('admin_id')->unsigned()->nullable();
            $table->boolean('success')->default(0);
            $table->string('failure_reason', 100)->nullable();
            $table->string('ip', 45)->nullable();
            $table->string('user_agent', 255)->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->index(['admin_id'], 'idx_login_admin');
            $table->index(['identifier', 'created_at'], 'idx_login_identifier_time');
            $table->index(['ip', 'created_at'], 'idx_login_ip_time');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('login_attempts');
    }
};
