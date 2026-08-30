<?php

declare(strict_types=1);

namespace App\Modules\Cron\Http\Controllers;

use App\Http\ApiResponse;
use App\Modules\Cron\Services\CatchUpAbsences;
use App\Modules\Cron\Services\PurgeKioskCaptures;
use App\Modules\Cron\Services\RunDailyAlerts;
use Illuminate\Http\JsonResponse;

/**
 * Ports of api/app/cron/*.php.
 *
 * Reachable over HTTP because that is how the installed crontab calls them —
 * `curl` with the shared secret. The work itself lives in App\Modules\Cron\Services and
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
