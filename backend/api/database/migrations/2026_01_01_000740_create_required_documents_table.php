<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('required_documents', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->string('name', 100);
            $table->text('description')->nullable();
            $table->integer('expiry_days')->unsigned()->nullable()->comment('Days before expiry, null = no expiry');
            $table->boolean('is_required')->default(1);
            $table->boolean('is_active')->default(1);
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->integer('notification_days_before')->nullable()->default(30)->comment('Days before expiry to send notification');
            $table->string('category', 50)->nullable()->default('general')->comment('identity|contract|certificate|insurance|general');
            $table->integer('sort_order')->nullable()->default(0);
            $table->enum('scope_type', ['all', 'branch', 'employees', 'category'])->default('all')->comment('all=every employee, branch=single branch, employees=specific list, category=by employee category');
            $table->integer('scope_branch_id')->unsigned()->nullable();
            $table->index(['scope_branch_id'], 'idx_reqdoc_scope_branch');
            $table->index(['tenant_id'], 'idx_reqdoc_tenant');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('required_documents');
    }
};
