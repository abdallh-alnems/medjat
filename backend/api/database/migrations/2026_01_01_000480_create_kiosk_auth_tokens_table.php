<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('kiosk_auth_tokens', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('station_id')->unsigned();
            $table->string('token_hash', 64)->comment('SHA-256 of the opaque token');
            $table->string('device_id', 100)->comment('Stable per tablet install');
            $table->timestamp('issued_at')->nullable()->useCurrent();
            $table->timestamp('last_used_at')->nullable()->useCurrent()->useCurrentOnUpdate();
            $table->timestamp('revoked_at')->nullable();
            $table->string('revoke_reason', 100)->nullable()->comment('unpaired | branch_deleted | replaced');
            $table->index(['tenant_id'], 'idx_kiosk_token_tenant');
            $table->unique(['station_id', 'revoked_at'], 'uniq_active_token_per_station');
            $table->unique(['token_hash'], 'uniq_kiosk_token_hash');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('kiosk_auth_tokens');
    }
};
