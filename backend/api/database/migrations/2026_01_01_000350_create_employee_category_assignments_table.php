<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('employee_category_assignments', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('employee_id')->unsigned();
            $table->integer('category_id')->unsigned();
            $table->index(['category_id', 'tenant_id'], 'idx_eca_category');
            $table->index(['tenant_id'], 'idx_eca_tenant');
            $table->unique(['employee_id', 'category_id'], 'uniq_emp_cat');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('employee_category_assignments');
    }
};
