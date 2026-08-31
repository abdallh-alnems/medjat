<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('employee_activation_codes', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('employee_id')->unsigned();
            $table->string('code', 12);
            $table->string('token', 64)->nullable()->comment('Long opaque secret for join link / QR; same row as code');
            $table->timestamp('expires_at');
            $table->timestamp('used_at')->nullable();
            $table->string('used_by_firebase_uid', 128)->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->index(['employee_id'], 'idx_act_employee');
            $table->index(['expires_at'], 'idx_act_expires');
            $table->index(['tenant_id'], 'idx_act_tenant');
            $table->unique(['code'], 'uniq_code');
            $table->unique(['token'], 'uniq_token');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('employee_activation_codes');
    }
};
