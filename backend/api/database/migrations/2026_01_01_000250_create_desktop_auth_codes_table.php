<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('desktop_auth_codes', function (Blueprint $table): void {
            $table->bigIncrements('id');
            $table->char('code_hash', 64)->comment('sha256 of the code handed to the browser');
            $table->char('state_hash', 64)->comment('sha256 of the nonce the desktop app generated');
            $table->integer('admin_id')->unsigned();
            $table->string('firebase_uid', 128);
            $table->dateTime('expires_at');
            $table->dateTime('used_at')->nullable();
            $table->dateTime('created_at')->useCurrent();
            $table->index(['admin_id'], 'fk_desktop_auth_admin');
            $table->index(['expires_at'], 'idx_desktop_auth_expires');
            $table->unique(['code_hash'], 'uk_desktop_auth_code');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('desktop_auth_codes');
    }
};
