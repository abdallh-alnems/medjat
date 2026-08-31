<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('approval_chains', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->string('name', 150);
            $table->string('name_ar', 150)->nullable();
            $table->string('request_type', 40)->comment('leave|expense|loan|bonus|warning|document|generic');
            $table->boolean('is_active')->default(1);
            $table->decimal('min_amount', 14, 2)->nullable()->comment('Condition: context amount >= this (NULL=no min)');
            $table->integer('branch_id')->unsigned()->nullable()->comment('Condition: request branch = this (NULL=all branches)');
            $table->integer('priority')->default(0)->comment('Higher wins when multiple chains match');
            $table->integer('created_by')->unsigned()->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->timestamp('updated_at')->nullable()->useCurrent()->useCurrentOnUpdate();
            $table->index(['created_by'], 'approval_chains_ibfk_3');
            $table->index(['branch_id'], 'idx_chain_branch');
            $table->index(['tenant_id', 'request_type', 'is_active'], 'idx_chain_tenant_type_active');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('approval_chains');
    }
};
