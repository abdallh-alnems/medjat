<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('employee_auth_tokens', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('employee_id')->unsigned();
            $table->string('token_hash', 64);
            $table->string('device_id', 100);
            $table->string('device_model', 100)->nullable();
            $table->enum('platform', ['android', 'ios', 'web']);
            $table->string('app_version', 20)->nullable();
            $table->timestamp('issued_at')->nullable()->useCurrent();
            $table->timestamp('last_used_at')->nullable()->useCurrent()->useCurrentOnUpdate();
            $table->timestamp('revoked_at')->nullable();
            $table->dateTime('expires_at')->nullable()->comment('NULL = never expires (app tokens). Web sessions set it; computed in SQL.');
            $table->string('revoke_reason', 100)->nullable();
            $table->index(['token_hash'], 'idx_emptoken_hash');
            $table->index(['tenant_id'], 'idx_emptoken_tenant');
            $table->index(['revoked_at', 'expires_at'], 'idx_token_active');
            $table->index(['employee_id', 'revoked_at'], 'idx_token_employee_revoked');
            $table->unique(['token_hash'], 'token_hash');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('employee_auth_tokens');
    }
};
