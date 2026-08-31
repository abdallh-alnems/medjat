<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('kiosk_codes', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('branch_id')->unsigned();
            $table->integer('station_id')->unsigned()->nullable()->comment('NULL for purpose=pair; set for purpose=access');
            $table->enum('purpose', ['pair', 'access']);
            $table->string('code_hash', 64)->comment('SHA-256; plaintext shown once and never stored');
            $table->dateTime('expires_at')->comment('ALWAYS computed in SQL: DATE_ADD(NOW(), INTERVAL ? SECOND). PHP runs UTC here and MySQL runs the tenant zone, so a PHP-computed expiry is born expired');
            $table->dateTime('used_at')->nullable()->comment('Non-null = consumed. Single use');
            $table->integer('used_by_station')->unsigned()->nullable();
            $table->integer('created_by')->unsigned()->comment('admins.id — who authorised this code. Carried onto every enrollment performed in the session it opens');
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->index(['branch_id', 'purpose'], 'idx_kiosk_code_branch');
            $table->index(['expires_at'], 'idx_kiosk_code_expires');
            $table->index(['code_hash', 'used_at', 'expires_at'], 'idx_kiosk_code_lookup');
            $table->index(['tenant_id'], 'kiosk_code_ibfk_tenant');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('kiosk_codes');
    }
};
