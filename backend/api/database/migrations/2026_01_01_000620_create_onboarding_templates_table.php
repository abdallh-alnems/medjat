<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('onboarding_templates', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->string('title', 200);
            $table->string('title_ar', 200)->nullable();
            $table->enum('task_type', ['document', 'asset', 'account', 'generic'])->default('generic');
            $table->text('description')->nullable();
            $table->integer('sort_order')->unsigned()->default(0);
            $table->boolean('is_active')->default(1);
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->index(['tenant_id', 'is_active', 'sort_order'], 'idx_onbtpl_tenant');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('onboarding_templates');
    }
};
