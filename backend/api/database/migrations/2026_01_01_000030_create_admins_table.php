<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('admins', function (Blueprint $table): void {
            $table->increments('id');
            $table->string('firebase_uid', 128)->nullable();
            $table->integer('tenant_id')->unsigned()->nullable()->comment('Null = user signed in but not joined a company yet');
            $table->integer('branch_id')->unsigned()->nullable();
            $table->string('name', 100);
            $table->string('phone', 20)->nullable();
            $table->string('email', 150)->nullable();
            $table->enum('auth_provider', ['email', 'google', 'apple', 'employee_code'])->default('email');
            $table->enum('role', ['general_manager', 'hr', 'branch_manager', 'attendance', 'viewer', 'employee', 'pending'])->default('pending');
            $table->boolean('is_active')->default(1);
            $table->timestamp('email_verified_at')->nullable();
            $table->timestamp('last_login_at')->nullable();
            $table->string('last_login_ip', 45)->nullable();
            $table->string('active_device_id', 100)->nullable()->comment('Most recent device that logged in; other devices are signed out on their next request');
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->timestamp('updated_at')->nullable()->useCurrent()->useCurrentOnUpdate();
            $table->unique(['firebase_uid'], 'firebase_uid');
            $table->index(['branch_id'], 'idx_admin_branch');
            $table->index(['email'], 'idx_admin_email');
            $table->index(['firebase_uid'], 'idx_admin_firebase');
            $table->index(['tenant_id'], 'idx_admin_tenant');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('admins');
    }
};
