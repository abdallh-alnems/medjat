<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('leave_year_balances', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('employee_id')->unsigned();
            $table->smallInteger('year');
            $table->integer('entitlement_days')->comment('Entitlement for this year at row-generation time');
            $table->integer('carried_over_days')->default(0)->comment('Days carried over from the previous year');
            $table->integer('carryover_encashed_days')->default(0)->comment('Days that were cashed out for this year instead of carried');
            $table->date('carryover_expires_on')->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->index(['tenant_id'], 'idx_lyb_tenant');
            $table->unique(['employee_id', 'year'], 'uk_lyb_employee_year');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('leave_year_balances');
    }
};
