<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('station_recognition_logs', function (Blueprint $table): void {
            $table->bigIncrements('id')->comment('bigint: one row per ATTEMPT, not per punch — the fastest-growing table in this feature');
            $table->integer('tenant_id')->unsigned();
            $table->integer('station_id')->unsigned();
            $table->integer('branch_id')->unsigned()->comment('Denormalised for reporting');
            $table->integer('employee_id')->unsigned()->nullable()->comment('NULL when nobody was identified — the whole reason this table exists');
            $table->enum('purpose', ['check_in', 'check_out', 'enroll'])->default('check_in');
            $table->enum('method', ['face', 'code'])->default('face');
            $table->enum('result', ['matched', 'ambiguous', 'no_match', 'below_threshold', 'liveness_failed', 'out_of_branch', 'spoofing_suspected', 'not_enrolled', 'wrong_method', 'too_soon', 'out_of_range', 'bad_embedding', 'model_mismatch']);
            $table->boolean('accepted')->default(0)->comment('Whether a punch was allowed through; 0 in log_only even when result=matched');
            $table->decimal('match_score', 4, 3)->nullable()->comment('Best candidate cosine similarity');
            $table->decimal('runner_up_score', 4, 3)->nullable()->comment('Second best — makes the margin rule auditable');
            $table->decimal('threshold', 4, 3)->nullable()->comment('Value in force at the time');
            $table->decimal('margin', 4, 3)->nullable()->comment('Value in force at the time');
            $table->smallInteger('candidates_searched')->unsigned()->nullable()->comment('Roster size at the moment of the attempt — correlate mis-attribution with N');
            $table->boolean('liveness_passed')->default(0);
            $table->string('challenge', 20)->nullable();
            $table->string('capture_path', 500)->nullable()->comment('Evidence image; NULL once purged, or never set for an unflagged failed attempt');
            $table->dateTime('capture_expires_at')->nullable()->comment('Computed in SQL. The purge unlinks the file and nulls capture_path; the row and its scores survive for tuning');
            $table->decimal('latitude', 10, 7)->nullable();
            $table->decimal('longitude', 10, 7)->nullable();
            $table->integer('attendance_id')->unsigned()->nullable()->comment('Set when the attempt produced a punch');
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->index(['tenant_id', 'employee_id', 'created_at'], 'idx_srl_employee');
            $table->index(['capture_expires_at'], 'idx_srl_purge');
            $table->index(['tenant_id', 'result', 'created_at'], 'idx_srl_result');
            $table->index(['station_id', 'created_at'], 'idx_srl_station');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('station_recognition_logs');
    }
};
