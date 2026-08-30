<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Modules\Cron\Services\CatchUpAbsences;
use Illuminate\Console\Command;

/**
 * The command-line face of the same job the cron URL runs.
 *
 * Both exist because the crontab currently calls the URL. Nothing lives in
 * either wrapper, so moving the server to the scheduler is a crontab change.
 */
final class CatchUpAbsencesCommand extends Command
{
    protected $signature = 'medjat:catch-up-absences';

    protected $description = 'Backfills absence records for every active company.';

    public function handle(CatchUpAbsences $job): int
    {
        $this->line((string) json_encode($job->execute(), JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT));

        return self::SUCCESS;
    }
}
