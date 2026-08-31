<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('tenants', function (Blueprint $table): void {
            $table->increments('id');
            $table->string('name', 100);
            $table->string('timezone', 50)->default('Africa/Cairo');
            $table->boolean('timezone_is_explicit')->default(0)->comment('Admin actually chose this timezone (vs sitting on the column default)');
            $table->string('currency', 3)->default('EGP');
            $table->char('country_code', 2)->nullable()->default('EG')->comment('ISO 3166-1 alpha-2; يحدّد مُصدِّر الرواتب الافتراضي');
            $table->boolean('is_active')->default(1);
            $table->timestamp('email_verified_at')->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->timestamp('updated_at')->nullable()->useCurrent()->useCurrentOnUpdate();
            $table->longText('attendance_methods')->nullable()->comment('Enabled methods, e.g. ["qr_gps","manual","station"]');
            $table->longText('manual_attendance_admin_ids')->nullable()->comment('NULL = all admins with manage_attendance; array = restricted set');
            $table->boolean('allow_offline_attendance')->default(1)->comment('Company-level toggle for offline attendance capture');
            $table->boolean('reject_mock_location')->default(0)->comment('Reject check-in/out when the device reports a mocked GPS location (Android only)');
            $table->boolean('require_local_biometric')->default(0)->comment('Require the phone fingerprint/FaceID gate on self check-in and check-out');
            $table->decimal('gps_latitude', 10, 7)->nullable();
            $table->decimal('gps_longitude', 10, 7)->nullable();
            $table->integer('gps_radius_meters')->nullable();
            $table->integer('default_annual_leave_days')->default(21)->comment('Default annual leave entitlement for all employees');
            $table->integer('leave_carryover_max_days')->nullable()->comment('NULL = no carryover; number = max days carried to next year');
            $table->boolean('auto_rollover_enabled')->default(0)->comment('1 = cron runs year-end rollover automatically on Jan 1');
            $table->boolean('apply_legal_seniority_entitlement')->default(1)->comment('1 = bump annual entitlement to >=30 days after 10 years service (Egyptian labour law)');
            $table->tinyInteger('cycle_start_day')->unsigned()->default(1)->comment('Attendance cycle start day (1-28); cycle labeled by its end month');
            $table->tinyInteger('week_start_day')->unsigned()->default(6)->comment('Weekly schedule start weekday (ISO: 1=Mon..7=Sun, default 6=Sat)');
            $table->date('last_absence_date')->nullable()->comment('Last completed day absences were materialized (lazy on-access catch-up)');
            $table->string('commercial_register', 60)->nullable()->comment('Commercial registration number shown on letters');
            $table->string('company_address', 255)->nullable();
            $table->string('company_phone', 30)->nullable();
            $table->decimal('face_match_threshold', 4, 3)->default(0.450)->comment('Minimum cosine similarity to accept a face match (see migration 2026_08_02)');
            $table->boolean('face_liveness_required')->default(1)->comment('Require the device to pass the server-issued liveness challenge');
            $table->enum('face_enforce_mode', ['log_only', 'enforce'])->default('log_only')->comment('log_only = record the score but never reject (tuning phase); enforce = reject below threshold');
            $table->boolean('web_attendance_enabled')->default(0)->comment('Allow employees to record attendance from a browser. Off for every existing company.');
            $table->boolean('web_attendance_photo_required')->default(1)->comment('Capture an image at each browser punch. On by default WHEN the channel is enabled.');
            $table->string('contact_name', 100)->nullable()->comment('Person we deal with at this company (billing/decisions), set by the super-admin panel');
            $table->string('contact_email', 150)->nullable()->comment('Contact email — not necessarily an admins.email, and not used for auth');
            $table->string('contact_phone', 30)->nullable()->comment('E.164 preferred (+20...) so the panel can dial / open WhatsApp directly');
            $table->text('ops_notes')->nullable()->comment('Internal support notes about this account. Never shown to the company.');
            $table->boolean('crew_photo_required')->default(0)->comment('Require a group photograph on every crew attendance batch.');
            $table->enum('face_replay_mode', ['log_only', 'enforce'])->default('log_only')->comment('What to do when an embedding is identical to an earlier attempt. Starts as log_only for every company.');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('tenants');
    }
};
