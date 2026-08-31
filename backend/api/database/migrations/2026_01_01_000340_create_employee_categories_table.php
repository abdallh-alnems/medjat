<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('employee_categories', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->string('name', 100);
            $table->text('description')->nullable();
            $table->string('color', 20)->nullable();
            $table->boolean('is_active')->default(1);
            $table->longText('attendance_methods')->nullable()->comment('NULL = inherit; array = category override (unioned across an employees categories)');
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->boolean('web_attendance_allowed')->nullable()->comment('NULL = inherit company. 1 = allowed. 0 = refused for this category.');
            $table->index(['tenant_id'], 'idx_ecat_tenant');
            $table->unique(['tenant_id', 'name'], 'uniq_category_tenant_name');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('employee_categories');
    }
};
