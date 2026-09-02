<?php

declare(strict_types=1);

namespace App\Modules\Cron\Console;

use Illuminate\Console\Command;
use Illuminate\Database\Migrations\Migrator;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Points this application at a database that already holds the schema.
 *
 * The migrations here build all 85 tables from empty, and none of them guards
 * with hasTable — deliberately, because MySQL 8 has no ADD COLUMN IF NOT EXISTS
 * and a migration that runs twice is a migration nobody can reason about. That
 * is correct for a fresh database and useless for the one cutover has to use:
 * production already has every table, and its `migrations` table is empty,
 * because the old backend tracked applied files in `schema_migrations` instead.
 *
 * So `php artisan migrate` against production would try CREATE TABLE tenants
 * and stop. This command is the missing step: it records the migrations whose
 * tables are already there as applied without running them, and actually runs
 * the ones whose tables are genuinely absent — which is how Laravel's own
 * `cache` and `jobs` tables get created, since the old backend never had them.
 *
 * Run once, at cutover, with --pretend first. It is not part of deploy.sh: a
 * deployment applies migrations, and something that decides not to run one has
 * to be a person's decision, made once, with the plan on screen.
 */
final class BaselineSchemaCommand extends Command
{
    protected $signature = 'medjat:baseline {--pretend : Show the plan and change nothing}';

    protected $description = 'Adopt an existing database: record already-present migrations as applied, run the rest';

    /**
     * Tables that prove this is a real Medjat database rather than an empty one
     * somebody meant to migrate normally.
     *
     * @var list<string>
     */
    private const SENTINELS = ['tenants', 'employees', 'attendance'];

    public function handle(Migrator $migrator): int
    {
        $pretend = (bool) $this->option('pretend');

        foreach (self::SENTINELS as $table) {
            if (! Schema::hasTable($table)) {
                $this->error("This database has no `{$table}` table, so there is nothing to adopt.");
                $this->line('For an empty database the right command is `php artisan migrate`.');

                return self::FAILURE;
            }
        }

        if (! $migrator->repositoryExists()) {
            if ($pretend) {
                $this->line('would create the `migrations` table');
            } else {
                $migrator->getRepository()->createRepository();
                $this->line('created the `migrations` table');
            }
        }

        // Everything already recorded is left alone, so a second run is a no-op
        // and an interrupted first run can simply be repeated.
        $recorded = $migrator->repositoryExists() ? $migrator->getRepository()->getRan() : [];
        $batch = $migrator->repositoryExists() ? $migrator->getRepository()->getNextBatchNumber() : 1;

        $adopt = [];
        $run = [];

        foreach ($this->migrationFiles($migrator) as $name => $path) {
            if (in_array($name, $recorded, true)) {
                continue;
            }

            $this->alreadyPresent($name) ? $adopt[] = $name : $run[$name] = $path;
        }

        $this->report($adopt, array_keys($run));

        if ($pretend) {
            $this->newLine();
            $this->comment('--pretend: nothing was changed.');

            return self::SUCCESS;
        }

        foreach ($adopt as $name) {
            $migrator->getRepository()->log($name, $batch);
        }

        foreach ($run as $name => $path) {
            $this->line("running {$name}");
            $migrator->runPending([$path], ['pretend' => false]);
        }

        $this->newLine();
        $this->info(sprintf(
            'Baselined: %d recorded as already applied, %d actually run.',
            count($adopt),
            count($run),
        ));

        return self::SUCCESS;
    }

    /**
     * @return array<string, string> migration name => absolute path
     */
    private function migrationFiles(Migrator $migrator): array
    {
        $files = $migrator->getMigrationFiles($migrator->paths() ?: [database_path('migrations')]);

        $named = [];
        foreach ($files as $path) {
            $named[$migrator->getMigrationName($path)] = $path;
        }

        return $named;
    }

    /**
     * Whether the thing this migration creates is already in the database.
     *
     * Decided from the database rather than from the filename alone, because a
     * wrong answer here is the difference between adopting a schema and
     * silently skipping a table that was never created.
     */
    private function alreadyPresent(string $migration): bool
    {
        if (preg_match('/_create_(\w+)_table$/', $migration, $matches) === 1) {
            return Schema::hasTable($matches[1]);
        }

        // The one migration that creates no table: it adds every foreign key at
        // the end. Production was built by the old backend, which declared its
        // keys inline, so if any foreign key exists in this schema the work is
        // already done.
        if (str_contains($migration, 'add_foreign_keys')) {
            return $this->hasAnyForeignKey();
        }

        // Anything else is new work by definition — this project's migrations
        // are all creates plus that one — so it runs.
        return false;
    }

    private function hasAnyForeignKey(): bool
    {
        $count = DB::table('information_schema.TABLE_CONSTRAINTS')
            ->where('CONSTRAINT_SCHEMA', DB::getDatabaseName())
            ->where('CONSTRAINT_TYPE', 'FOREIGN KEY')
            ->count();

        return $count > 0;
    }

    /**
     * @param  list<string>  $adopt
     * @param  list<string>  $run
     */
    private function report(array $adopt, array $run): void
    {
        $this->newLine();
        $this->line(sprintf('<options=bold>%d migrations already present</> — recorded, not run:', count($adopt)));
        foreach ($adopt as $name) {
            $this->line("  · {$name}");
        }

        $this->newLine();
        $this->line(sprintf('<options=bold>%d migrations to run</> — their tables do not exist yet:', count($run)));
        foreach ($run as $name) {
            $this->line("  + {$name}");
        }

        if ($run === []) {
            $this->line('  (none)');
        }
    }
}
