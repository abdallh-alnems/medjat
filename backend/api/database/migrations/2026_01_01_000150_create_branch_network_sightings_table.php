<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('branch_network_sightings', function (Blueprint $table): void {
            $table->bigIncrements('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('branch_id')->unsigned();
            $table->integer('employee_id')->unsigned();
            $table->string('bssid', 64)->nullable();
            $table->string('ssid', 100)->nullable();
            $table->string('client_ip', 45)->nullable();
            $table->boolean('inside_geofence')->default(0);
            $table->integer('distance_meters')->nullable();
            $table->timestamp('seen_at')->nullable()->useCurrent();
            $table->index(['tenant_id', 'branch_id', 'seen_at'], 'idx_sighting_branch');
            $table->index(['tenant_id', 'branch_id', 'bssid'], 'idx_sighting_bssid');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('branch_network_sightings');
    }
};
