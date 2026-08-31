<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('super_admin_sessions', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('admin_id')->unsigned();
            $table->string('token_hash', 64);
            $table->timestamp('expires_at');
            $table->string('ip', 45)->nullable();
            $table->string('user_agent', 255)->nullable();
            $table->timestamp('last_used_at')->nullable()->useCurrent()->useCurrentOnUpdate();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->index(['admin_id'], 'idx_session_admin');
            $table->index(['token_hash'], 'idx_session_hash');
            $table->unique(['token_hash'], 'token_hash');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('super_admin_sessions');
    }
};
