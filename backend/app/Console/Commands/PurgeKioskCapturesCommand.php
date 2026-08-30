<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Modules\Cron\Services\PurgeKioskCaptures;
use Illuminate\Console\Command;

/**
 * The command-line face of the same job the cron URL runs.
 *
 * Both exist because the crontab currently calls the URL. Nothing lives in
 * either wrapper, so moving the server to the scheduler is a crontab change.
 */
final class PurgeKioskCapturesCommand extends Command
{
    protected $signature = 'medjat:purge-kiosk-captures';

    protected $description = 'Deletes kiosk captures whose retention window has passed.';

    public function handle(PurgeKioskCaptures $job): int
    {
        $this->line((string) json_encode($job->execute(), JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT));

        return self::SUCCESS;
    }
}
