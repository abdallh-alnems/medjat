<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('leave_encashments', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('employee_id')->unsigned();
            $table->smallInteger('source_year')->comment('Year whose remaining balance is being cashed out');
            $table->integer('days')->default(0);
            $table->decimal('daily_rate', 12, 2)->default(0.00);
            $table->decimal('amount', 12, 2)->default(0.00);
            $table->enum('status', ['pending', 'paid', 'cancelled'])->default('pending');
            $table->string('payroll_month', 7)->nullable()->comment('YYYY-MM where it was paid');
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->timestamp('updated_at')->nullable()->useCurrent()->useCurrentOnUpdate();
            $table->index(['tenant_id', 'payroll_month'], 'idx_enc_month');
            $table->index(['tenant_id'], 'idx_enc_tenant');
            $table->unique(['employee_id', 'source_year'], 'uk_enc_employee_year');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('leave_encashments');
    }
};
