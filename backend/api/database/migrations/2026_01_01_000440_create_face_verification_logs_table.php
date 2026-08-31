<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('face_verification_logs', function (Blueprint $table): void {
            $table->bigIncrements('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('employee_id')->unsigned();
            $table->integer('branch_id')->unsigned()->nullable();
            $table->enum('purpose', ['check_in', 'check_out'])->default('check_in');
            $table->enum('result', ['matched', 'below_threshold', 'liveness_failed', 'not_enrolled', 'invalid_challenge', 'bad_embedding', 'model_mismatch', 'replayed_embedding']);
            $table->boolean('accepted')->default(0)->comment('Whether the punch was allowed through (log_only mode accepts below-threshold)');
            $table->decimal('match_score', 4, 3)->nullable();
            $table->decimal('threshold', 4, 3)->nullable();
            $table->boolean('liveness_passed')->default(0);
            $table->string('challenge', 20)->nullable();
            $table->decimal('latitude', 10, 7)->nullable();
            $table->decimal('longitude', 10, 7)->nullable();
            $table->string('selfie_path', 500)->nullable();
            $table->boolean('is_mock_location')->default(0);
            $table->boolean('is_rooted_device')->default(0);
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->char('embedding_hash', 64)->nullable()->comment('SHA-256 of the quantised embedding. One-way: proves two attempts were identical without storing the biometric template again.');
            $table->index(['tenant_id', 'employee_id', 'created_at'], 'idx_fvl_employee');
            $table->index(['tenant_id', 'employee_id', 'embedding_hash'], 'idx_fvl_replay');
            $table->index(['tenant_id', 'result', 'created_at'], 'idx_fvl_result');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('face_verification_logs');
    }
};
