<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('leave_carryover_policies', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->enum('scope_type', ['tenant', 'branch', 'category', 'employee'])->default('tenant');
            $table->integer('scope_id')->unsigned()->nullable()->comment('branch/category/employee id; NULL for tenant scope');
            $table->integer('min_seniority_months')->unsigned()->default(0)->comment('Seniority tier threshold in months (0 = applies to everyone)');
            $table->boolean('carryover_enabled')->default(1)->comment('0 = remaining is dropped (unless legal_min/encash apply)');
            $table->integer('carryover_max_days')->nullable()->comment('Max days carried; NULL = unlimited');
            $table->integer('expiry_months')->unsigned()->nullable()->comment('Carried days expire N months into the new year; NULL = never');
            $table->boolean('encash_excess')->default(0)->comment('Pay out days above the cap instead of dropping them');
            $table->integer('legal_min_carry_days')->unsigned()->nullable()->comment('Statutory floor that must be carried or encashed, never forfeited');
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->timestamp('updated_at')->nullable()->useCurrent()->useCurrentOnUpdate();
            $table->index(['tenant_id'], 'idx_lcp_tenant');
            $table->unique(['tenant_id', 'scope_type', 'scope_id', 'min_seniority_months'], 'uk_lcp_scope');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('leave_carryover_policies');
    }
};
