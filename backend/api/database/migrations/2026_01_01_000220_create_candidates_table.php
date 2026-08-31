<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('candidates', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('job_opening_id')->unsigned()->nullable();
            $table->string('name', 150);
            $table->string('email', 190)->nullable();
            $table->string('phone', 20)->nullable();
            $table->string('cv_url', 512)->nullable();
            $table->string('source', 80)->nullable()->comment('referral|walk_in|agency|manual...');
            $table->enum('stage', ['applied', 'screening', 'interview', 'offer', 'hired', 'rejected'])->default('applied');
            $table->decimal('expected_salary', 12, 2)->nullable();
            $table->text('notes')->nullable();
            $table->text('rejection_reason')->nullable();
            $table->integer('converted_employee_id')->unsigned()->nullable()->comment('set when stage=hired and converted');
            $table->integer('created_by')->unsigned()->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->timestamp('updated_at')->nullable()->useCurrent()->useCurrentOnUpdate();
            $table->index(['created_by'], 'candidates_ibfk_4');
            $table->index(['converted_employee_id'], 'idx_cand_emp');
            $table->index(['job_opening_id'], 'idx_cand_job');
            $table->index(['tenant_id', 'stage'], 'idx_cand_tenant_stage');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('candidates');
    }
};
