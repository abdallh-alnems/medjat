<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('holidays', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('branch_id')->unsigned()->nullable()->comment('Null = all branches');
            $table->string('name', 100);
            $table->date('date');
            $table->text('notes')->nullable();
            $table->integer('created_by')->unsigned()->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->timestamp('updated_at')->nullable()->useCurrent()->useCurrentOnUpdate();
            $table->index(['branch_id'], 'branch_id');
            $table->index(['created_by'], 'created_by');
            $table->index(['date'], 'idx_holiday_date');
            $table->unique(['tenant_id', 'branch_id', 'date'], 'uniq_holiday_branch_date');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('holidays');
    }
};
