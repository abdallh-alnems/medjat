<?php

declare(strict_types=1);

namespace App\Shared\Docs;

use Illuminate\Console\Command;

/**
 * Writes docs/openapi.json from the routing table.
 *
 * The output is committed, and a test regenerates it and compares. A new route
 * therefore fails the build until the document is regenerated, which is the only
 * way a description of three hundred endpoints stays true.
 */
final class GenerateOpenApiCommand extends Command
{
    protected $signature = 'medjat:openapi {--check : Fail if the committed document is out of date}';

    protected $description = 'Generates the OpenAPI description of the API.';

    public function handle(OpenApiGenerator $generator): int
    {
        $path = base_path('docs/openapi.json');
        $json = json_encode(
            $generator->generate(),
            JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE,
        )."\n";

        if ($this->option('check')) {
            $current = is_file($path) ? file_get_contents($path) : null;

            if ($current !== $json) {
                $this->error('docs/openapi.json is out of date. Run: php artisan medjat:openapi');

                return self::FAILURE;
            }

            $this->info('docs/openapi.json is up to date.');

            return self::SUCCESS;
        }

        if (! is_dir(dirname($path))) {
            mkdir(dirname($path), 0o755, true);
        }

        file_put_contents($path, $json);
        $this->info('Wrote '.$path);

        return self::SUCCESS;
    }
}
