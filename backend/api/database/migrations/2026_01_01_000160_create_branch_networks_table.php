<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('branch_networks', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('branch_id')->unsigned();
            $table->enum('kind', ['bssid', 'ip_v4', 'ip_cidr'])->default('bssid');
            $table->string('value', 64)->comment('BSSID normalised to lower-case colon form, or an IPv4 / CIDR');
            $table->string('label', 100)->nullable();
            $table->enum('source', ['captured', 'discovered', 'manual'])->default('discovered');
            $table->boolean('is_active')->default(1);
            $table->integer('approved_by')->unsigned()->nullable();
            $table->dateTime('approved_at')->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->index(['tenant_id', 'branch_id', 'is_active'], 'idx_branch_network_lookup');
            $table->unique(['tenant_id', 'branch_id', 'kind', 'value'], 'uniq_branch_network');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('branch_networks');
    }
};
