<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('deduction_rules', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->string('rule_key', 50);
            $table->enum('rule_type', ['numeric', 'text', 'boolean'])->default('numeric');
            $table->string('rule_value', 255);
            $table->text('description')->nullable();
            $table->boolean('is_active')->default(1);
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->timestamp('updated_at')->nullable()->useCurrent()->useCurrentOnUpdate();
            $table->unique(['tenant_id', 'rule_key'], 'uniq_deduction_rule');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('deduction_rules');
    }
};
