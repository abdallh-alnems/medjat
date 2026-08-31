<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('admin_notification_prefs', function (Blueprint $table): void {
            $table->integer('admin_id')->unsigned();
            $table->integer('tenant_id')->unsigned()->nullable();
            $table->longText('prefs');
            $table->timestamp('updated_at')->useCurrent()->useCurrentOnUpdate();
            $table->index(['tenant_id'], 'idx_notif_prefs_tenant');
            $table->primary(['admin_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('admin_notification_prefs');
    }
};
