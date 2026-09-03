<?php

declare(strict_types=1);

use Illuminate\Support\Facades\Schedule;

/*
|--------------------------------------------------------------------------
| Scheduled jobs
|--------------------------------------------------------------------------
|
| Mirrors what /etc/cron.d/permedjat currently invokes over HTTP, so the server
| can switch to `schedule:run` without deciding the times again. Africa/Cairo,
| matching the crontab, because the alert digest is meant to land before the
| working day rather than at some hour of UTC.
|
| withoutOverlapping because the alert run walks every company: a slow run must
| queue behind itself rather than doubling up and racing its own dedupe.
|
*/

Schedule::command('permedjat:run-alerts')
    ->dailyAt('07:00')
    ->timezone('Africa/Cairo')
    ->withoutOverlapping();

Schedule::command('permedjat:catch-up-absences')
    ->dailyAt('23:50')
    ->timezone('Africa/Cairo')
    ->withoutOverlapping();

Schedule::command('permedjat:purge-kiosk-captures')
    ->dailyAt('03:30')
    ->timezone('Africa/Cairo')
    ->withoutOverlapping();
