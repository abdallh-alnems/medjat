<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('open_shifts', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('branch_id')->unsigned()->nullable()->comment('NULL = all branches eligible');
            $table->integer('shift_id')->unsigned();
            $table->date('work_date');
            $table->tinyInteger('slots')->unsigned()->default(1);
            $table->tinyInteger('slots_filled')->unsigned()->default(0);
            $table->enum('status', ['open', 'filled', 'cancelled'])->default('open');
            $table->string('notes', 255)->nullable();
            $table->integer('created_by')->unsigned()->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->index(['branch_id'], 'idx_openshift_branch');
            $table->index(['tenant_id', 'status', 'work_date'], 'idx_openshift_tenant_status');
            $table->index(['shift_id'], 'open_shifts_ibfk_2');
            $table->index(['created_by'], 'open_shifts_ibfk_4');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('open_shifts');
    }
};
