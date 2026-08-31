<?php

declare(strict_types=1);

namespace App\Modules\Cron\Console;

use App\Modules\Cron\Services\RunDailyAlerts;
use Illuminate\Console\Command;

/**
 * The command-line face of the same job the cron URL runs.
 *
 * Both exist because the crontab currently calls the URL. Nothing lives in
 * either wrapper, so moving the server to the scheduler is a crontab change.
 */
final class RunDailyAlertsCommand extends Command
{
    protected $signature = 'medjat:run-alerts';

    protected $description = 'Sends the daily manager alerts.';

    public function handle(RunDailyAlerts $job): int
    {
        $this->line((string) json_encode($job->execute(), JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT));

        return self::SUCCESS;
    }
}
