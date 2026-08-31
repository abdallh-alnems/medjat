<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('shifts', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('branch_id')->unsigned()->nullable()->comment('NULL = available for all branches');
            $table->string('name', 100)->comment('e.g. "Morning", "Evening", "Night"');
            $table->time('start_time');
            $table->time('end_time');
            $table->string('color', 7)->nullable()->comment('Hex color for UI badge');
            $table->boolean('is_active')->default(1);
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->timestamp('updated_at')->nullable()->useCurrent()->useCurrentOnUpdate();
            $table->index(['branch_id'], 'idx_shift_branch');
            $table->index(['tenant_id'], 'idx_shift_tenant');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('shifts');
    }
};
