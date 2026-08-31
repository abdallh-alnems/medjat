<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('super_admins', function (Blueprint $table): void {
            $table->increments('id');
            $table->string('username', 50);
            $table->string('firebase_uid', 128)->nullable();
            $table->string('email', 150)->nullable();
            $table->string('password_hash', 255);
            $table->string('display_name', 100)->nullable();
            $table->enum('role', ['readonly', 'admin', 'superadmin'])->default('admin');
            $table->boolean('is_active')->default(1);
            $table->timestamp('last_login_at')->nullable();
            $table->string('last_login_ip', 45)->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->timestamp('updated_at')->nullable()->useCurrent()->useCurrentOnUpdate();
            $table->unique(['email'], 'email');
            $table->unique(['firebase_uid'], 'super_admins_firebase_uid_unique');
            $table->unique(['username'], 'username');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('super_admins');
    }
};
