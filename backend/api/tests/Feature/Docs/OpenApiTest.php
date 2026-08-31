<?php

declare(strict_types=1);

namespace Tests\Feature\Docs;

use App\Shared\Docs\OpenApiGenerator;
use App\Support\Value;
use Illuminate\Support\Facades\Route;
use Tests\TestCase;

/**
 * The API description, and whether it still describes the API.
 *
 * A document generated once and committed is a document that starts lying on
 * the next merge. The check here is that regenerating produces exactly what is
 * on disk, so adding a route fails the build until `php artisan medjat:openapi`
 * has been run.
 */
final class OpenApiTest extends TestCase
{
    /**
     * @return array<string, mixed>
     */
    private function generated(): array
    {
        return app(OpenApiGenerator::class)->generate();
    }

    /**
     * Narrows a decoded JSON node, so the assertions below can walk the
     * document without PHPStan taking every step on faith.
     *
     * @return array<array-key, mixed>
     */
    private function node(mixed $value): array
    {
        $this->assertIsArray($value);

        return $value;
    }

    /**
     * @return array<string, mixed>
     */
    private function committed(): array
    {
        $raw = file_get_contents(base_path('docs/openapi.json'));
        $this->assertIsString($raw, 'docs/openapi.json is missing');

        /** @var array<string, mixed> $decoded */
        $decoded = json_decode($raw, true, 512, JSON_THROW_ON_ERROR);

        return $decoded;
    }

    public function test_the_committed_document_matches_the_routing_table(): void
    {
        $this->assertSame(
            $this->generated(),
            $this->committed(),
            'docs/openapi.json is stale — run: php artisan medjat:openapi',
        );
    }

    public function test_every_route_is_described(): void
    {
        $paths = $this->node($this->committed()['paths']);
        $described = 0;

        foreach ($paths as $methods) {
            $described += count($this->node($methods));
        }

        $routed = 0;

        /** @var list<\Illuminate\Routing\Route> $all */
        $all = Route::getRoutes()->getRoutes();

        foreach ($all as $route) {
            if (in_array($route->uri(), ['up', 'storage/{path}'], true)) {
                continue;
            }

            /** @var list<string> $methods */
            $methods = $route->methods();

            foreach ($methods as $method) {
                if (! in_array($method, ['HEAD', 'OPTIONS'], true)) {
                    $routed++;
                }
            }
        }

        $this->assertSame($routed, $described);
    }

    public function test_operation_ids_are_unique(): void
    {
        // OpenAPI requires it, and a route answering several verbs shares one
        // route name — the terminal endpoint answers five.
        $ids = [];

        foreach ($this->node($this->committed()['paths']) as $methods) {
            foreach ($this->node($methods) as $operation) {
                $ids[] = Value::string($this->node($operation)['operationId'] ?? null);
            }
        }

        $this->assertSame(array_unique($ids), $ids, 'duplicate operationId');
    }

    public function test_every_authenticated_route_names_its_principal(): void
    {
        // The one thing a caller gets wrong first is which token to send, so a
        // route that is guarded but does not say by what is worse than useless.
        foreach ($this->node($this->committed()['paths']) as $path => $methods) {
            foreach ($this->node($methods) as $verb => $operation) {
                $op = $this->node($operation);
                $security = $this->node($op['security'] ?? []);

                if ($security === []) {
                    $this->assertArrayHasKey(
                        'description',
                        $op,
                        "{$verb} {$path} has no principal and does not say it is open",
                    );
                }
            }
        }
    }
}
