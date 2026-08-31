<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('force_updates', function (Blueprint $table): void {
            $table->bigIncrements('id');
            $table->enum('platform', ['all', 'android', 'ios'])->default('all');
            $table->string('min_version', 20);
            $table->string('message', 255)->nullable();
            $table->boolean('is_active')->default(1);
            $table->timestamp('created_at')->nullable();
            $table->timestamp('updated_at')->nullable();
            $table->unique(['platform'], 'force_updates_platform_unique');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('force_updates');
    }
};
