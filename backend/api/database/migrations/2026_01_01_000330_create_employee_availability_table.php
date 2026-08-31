<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('employee_availability', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('employee_id')->unsigned();
            $table->enum('kind', ['weekly', 'date'])->default('weekly');
            $table->tinyInteger('day_of_week')->unsigned()->nullable()->comment('0=Sun..6=Sat');
            $table->date('specific_date')->nullable()->comment('for kind=date');
            $table->enum('availability', ['available', 'preferred', 'unavailable'])->default('available');
            $table->time('start_time')->nullable();
            $table->time('end_time')->nullable();
            $table->string('note', 255)->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->timestamp('updated_at')->nullable()->useCurrent()->useCurrentOnUpdate();
            $table->index(['employee_id'], 'employee_availability_ibfk_2');
            $table->index(['specific_date'], 'idx_avail_date');
            $table->index(['tenant_id', 'employee_id', 'kind'], 'idx_avail_tenant_emp');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('employee_availability');
    }
};
