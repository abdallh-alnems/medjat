<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('support_messages', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('ticket_id')->unsigned();
            $table->enum('sender_type', ['user', 'support', 'system']);
            $table->integer('sender_admin_id')->unsigned()->nullable()->comment('admins.id if sender_type=user');
            $table->integer('sender_super_admin_id')->unsigned()->nullable()->comment('super_admins.id if sender_type=support');
            $table->text('body');
            $table->string('attachment_url', 500)->nullable();
            $table->string('attachment_name', 255)->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->index(['ticket_id', 'id'], 'idx_support_messages_ticket');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('support_messages');
    }
};
