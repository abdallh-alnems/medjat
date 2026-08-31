<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('custom_roles', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('admin_id')->unsigned();
            $table->integer('branch_id')->unsigned()->nullable()->comment('Scope: null = all branches');
            $table->string('name', 50);
            $table->longText('permissions');
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->timestamp('updated_at')->nullable()->useCurrent()->useCurrentOnUpdate();
            $table->index(['branch_id'], 'branch_id');
            $table->index(['tenant_id'], 'idx_custrole_tenant');
            $table->unique(['tenant_id', 'admin_id'], 'uniq_role_admin');
            $table->index(['admin_id'], 'user_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('custom_roles');
    }
};
