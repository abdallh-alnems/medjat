<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('notifications', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned()->nullable()->comment('Null = system-wide from super admin');
            $table->integer('admin_id')->unsigned()->nullable();
            $table->integer('employee_id')->unsigned()->nullable()->comment('For Employee-app recipients');
            $table->enum('type', ['general', 'attendance', 'payroll', 'leave', 'warning', 'system', 'invite', 'support', 'approval'])->default('general');
            $table->string('title', 255);
            $table->string('title_ar', 255)->nullable();
            $table->text('body');
            $table->text('body_ar')->nullable();
            $table->longText('data')->nullable();
            $table->set('sent_via', ['push', 'email', 'in_app'])->default('in_app');
            $table->timestamp('read_at')->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->index(['admin_id', 'read_at'], 'idx_notif_admin_read');
            $table->index(['employee_id', 'read_at'], 'idx_notif_emp_read');
            $table->index(['tenant_id'], 'idx_notif_tenant');
            $table->index(['type'], 'idx_notif_type');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('notifications');
    }
};
