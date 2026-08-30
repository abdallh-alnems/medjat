<?php

declare(strict_types=1);

namespace App\Http\Controllers\Cron;

use App\Http\ApiResponse;
use App\Services\Cron\CatchUpAbsences;
use App\Services\Cron\PurgeKioskCaptures;
use App\Services\Cron\RunDailyAlerts;
use Illuminate\Http\JsonResponse;

/**
 * Ports of api/app/cron/*.php.
 *
 * Reachable over HTTP because that is how the installed crontab calls them —
 * `curl` with the shared secret. The work itself lives in App\Services\Cron and
 * is also exposed as artisan commands, so the server can move to the scheduler
 * without touching any of this.
 */
final class CronController
{
    public function catchUpAbsences(CatchUpAbsences $job): JsonResponse
    {
        return ApiResponse::success($job->execute());
    }

    public function runAlerts(RunDailyAlerts $job): JsonResponse
    {
        return ApiResponse::success($job->execute());
    }

    public function purgeKioskCaptures(PurgeKioskCaptures $job): JsonResponse
    {
        return ApiResponse::success($job->execute());
    }
}
