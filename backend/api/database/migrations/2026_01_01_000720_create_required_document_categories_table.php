<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('required_document_categories', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('required_document_id')->unsigned();
            $table->integer('category_id')->unsigned();
            $table->index(['category_id', 'tenant_id'], 'idx_rdc_category');
            $table->index(['tenant_id'], 'idx_rdc_tenant');
            $table->unique(['required_document_id', 'category_id'], 'uniq_rdoc_cat');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('required_document_categories');
    }
};
