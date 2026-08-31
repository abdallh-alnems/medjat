<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('device_protocol_logs', function (Blueprint $table): void {
            $table->bigIncrements('id');
            $table->integer('device_id')->unsigned()->nullable();
            $table->string('serial_number', 64)->nullable();
            $table->string('method', 8)->nullable();
            $table->string('path', 120)->nullable();
            $table->string('query_string', 500)->nullable();
            $table->text('body')->nullable();
            $table->text('response')->nullable();
            $table->string('client_ip', 45)->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->index(['created_at'], 'idx_protocol_created');
            $table->index(['device_id', 'id'], 'idx_protocol_device');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('device_protocol_logs');
    }
};
