<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('admin_devices', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('admin_id')->unsigned();
            $table->string('fcm_token', 500);
            $table->enum('platform', ['android', 'ios', 'web'])->default('android');
            $table->string('device_id', 100)->nullable();
            $table->string('device_model', 100)->nullable();
            $table->string('app_version', 20)->nullable();
            $table->boolean('is_active')->default(1);
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->timestamp('updated_at')->nullable()->useCurrent()->useCurrentOnUpdate();
            $table->index(['fcm_token'], 'idx_device_token');
            $table->unique(['admin_id', 'device_id'], 'uniq_device_admin');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('admin_devices');
    }
};
