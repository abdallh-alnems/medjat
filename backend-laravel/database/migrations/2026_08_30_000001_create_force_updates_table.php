<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * The table api/admin/force_update/trigger.php has always written to, and which
 * has never existed.
 *
 * It appears in no migration, in no schema dump taken from production, and
 * nowhere else in the original codebase — so every press of that button in the
 * admin panel returned a 500. The endpoint is ported faithfully, which means
 * the table it needs has to exist.
 *
 * Distinct from the Remote Config gate: that one is keyed by app
 * (medjat_app, medjat_central, medjat_kiosk), while this is keyed by platform,
 * which is the axis the store build of a given app cannot express.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('force_updates', function (Blueprint $table): void {
            $table->id();
            // 'all' is a real value, not a wildcard: one row saying everybody
            // must update, alongside per-platform rows when they diverge.
            $table->enum('platform', ['all', 'android', 'ios'])->default('all')->unique();
            $table->string('min_version', 20);
            $table->string('message', 255)->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('force_updates');
    }
};
