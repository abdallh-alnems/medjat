<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('late_deduction_tiers', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('threshold_minutes')->unsigned();
            $table->decimal('deduction_days', 5, 2);
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->timestamp('updated_at')->nullable()->useCurrent()->useCurrentOnUpdate();
            $table->unique(['tenant_id', 'threshold_minutes'], 'uniq_tenant_threshold');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('late_deduction_tiers');
    }
};
