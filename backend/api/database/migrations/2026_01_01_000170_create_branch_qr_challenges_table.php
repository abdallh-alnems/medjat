<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('branch_qr_challenges', function (Blueprint $table): void {
            $table->bigIncrements('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('branch_id')->unsigned();
            $table->char('nonce', 64)->comment('32 random bytes hex. This is the value encoded in the displayed QR.');
            $table->dateTime('expires_at')->comment('Computed by MySQL (DATE_ADD(NOW(), ...)), never by PHP.');
            $table->integer('issued_by')->unsigned()->nullable()->comment('admins.id that opened the display');
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->index(['tenant_id'], 'branch_qr_challenges_tenant_fk');
            $table->index(['branch_id', 'expires_at'], 'idx_branch_qr_lookup');
            $table->index(['expires_at'], 'idx_branch_qr_purge');
            $table->unique(['nonce'], 'uniq_branch_qr_nonce');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('branch_qr_challenges');
    }
};
