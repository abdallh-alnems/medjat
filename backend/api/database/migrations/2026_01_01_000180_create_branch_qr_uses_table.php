<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('branch_qr_uses', function (Blueprint $table): void {
            $table->bigIncrements('id');
            $table->bigInteger('challenge_id')->unsigned();
            $table->integer('employee_id')->unsigned();
            $table->enum('purpose', ['check_in', 'check_out'])->default('check_in')->comment('An employee arriving and leaving inside one window is legitimate; the same purpose twice is not.');
            $table->timestamp('used_at')->nullable()->useCurrent();
            $table->index(['employee_id'], 'idx_branch_qr_use_emp');
            $table->unique(['challenge_id', 'employee_id', 'purpose'], 'uniq_branch_qr_use');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('branch_qr_uses');
    }
};
