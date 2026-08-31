<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('face_challenges', function (Blueprint $table): void {
            $table->bigIncrements('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('employee_id')->unsigned()->nullable()->comment('NULL for kiosk challenges: at challenge time the identity is not yet known');
            $table->char('nonce', 64);
            $table->enum('challenge', ['blink', 'turn_left', 'turn_right', 'smile']);
            $table->enum('purpose', ['check_in', 'check_out', 'enroll'])->default('check_in');
            $table->dateTime('expires_at');
            $table->dateTime('consumed_at')->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->index(['tenant_id', 'employee_id', 'expires_at'], 'idx_face_challenge_lookup');
            $table->unique(['nonce'], 'uniq_face_challenge_nonce');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('face_challenges');
    }
};
