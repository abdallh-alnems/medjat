<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('employee_web_credentials', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('employee_id')->unsigned();
            $table->string('pin_hash', 255)->comment('password_hash() of the 6-digit PIN — never the PIN itself');
            $table->tinyInteger('failed_attempts')->unsigned()->default(0);
            $table->dateTime('locked_until')->nullable()->comment('Set in SQL, never computed in PHP (PHP runs UTC, MySQL does not)');
            $table->dateTime('pin_set_at');
            $table->dateTime('last_used_at')->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->timestamp('updated_at')->nullable()->useCurrent()->useCurrentOnUpdate();
            $table->index(['tenant_id'], 'idx_web_credential_tenant');
            $table->unique(['employee_id'], 'uniq_web_credential_employee');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('employee_web_credentials');
    }
};
