<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('schema_migrations', function (Blueprint $table): void {
            $table->string('filename', 191);
            $table->char('checksum', 64);
            $table->timestamp('applied_at')->useCurrent();
            $table->string('applied_by', 64)->nullable();
            $table->primary(['filename']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('schema_migrations');
    }
};
