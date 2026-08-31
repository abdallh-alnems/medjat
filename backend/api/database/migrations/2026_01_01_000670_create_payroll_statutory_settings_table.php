<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('payroll_statutory_settings', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->boolean('social_insurance_enabled')->default(0);
            $table->decimal('si_employee_rate', 5, 2)->nullable();
            $table->decimal('si_min_wage', 12, 2)->nullable();
            $table->decimal('si_max_wage', 12, 2)->nullable();
            $table->boolean('income_tax_enabled')->default(0);
            $table->longText('income_tax_brackets')->nullable();
            $table->decimal('tax_personal_exemption', 12, 2)->nullable();
            $table->boolean('eosb_enabled')->default(0);
            $table->decimal('eosb_days_per_year', 5, 2)->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->timestamp('updated_at')->nullable()->useCurrent()->useCurrentOnUpdate();
            $table->unique(['tenant_id'], 'uk_statutory_tenant');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('payroll_statutory_settings');
    }
};
