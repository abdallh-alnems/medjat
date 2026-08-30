<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * The column api/admin/auth/login.php's Google branch has always read and
 * written, and which has never existed.
 *
 * That branch selects `firebase_uid` from `super_admins` and updates it on
 * first sign-in, but the column is absent from the production-derived dump —
 * so every attempt to sign in to the panel with Google died on a SQL error
 * before it reached any of the checks. Only the username-and-password path has
 * ever worked.
 *
 * Nullable, because an operator who only ever uses a password has no uid, and
 * unique, because two accounts claiming the same Google identity would make
 * "who is signing in" unanswerable.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('super_admins', function (Blueprint $table): void {
            $table->string('firebase_uid', 128)->nullable()->unique()->after('username');
        });
    }

    public function down(): void
    {
        Schema::table('super_admins', function (Blueprint $table): void {
            $table->dropColumn('firebase_uid');
        });
    }
};
