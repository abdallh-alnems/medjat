<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('job_openings', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('branch_id')->unsigned()->nullable();
            $table->string('title', 150);
            $table->string('department', 100)->nullable();
            $table->text('description')->nullable();
            $table->enum('employment_type', ['full_time', 'part_time', 'contract', 'temporary'])->default('full_time');
            $table->integer('openings_count')->unsigned()->default(1);
            $table->enum('status', ['open', 'on_hold', 'closed'])->default('open');
            $table->integer('created_by')->unsigned()->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->timestamp('closed_at')->nullable();
            $table->index(['branch_id'], 'idx_job_branch');
            $table->index(['tenant_id', 'status'], 'idx_job_tenant_status');
            $table->index(['created_by'], 'job_openings_ibfk_3');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('job_openings');
    }
};
