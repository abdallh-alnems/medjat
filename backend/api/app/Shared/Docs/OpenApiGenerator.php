<?php

declare(strict_types=1);

namespace App\Shared\Docs;

use App\Support\Value;
use Illuminate\Routing\Route;
use Illuminate\Support\Facades\Route as Router;
use Illuminate\Support\Str;
use ReflectionClass;
use ReflectionException;

/**
 * Describes the API from the routing table.
 *
 * Deliberately not an annotation- or type-inference package. Those read request
 * and response classes to learn the shape of a call, and this application has
 * neither: handlers take `$request->input(...)` and hand back arrays. Pointed at
 * this code, such a tool produces a list of paths with empty bodies and calls it
 * documentation.
 *
 * What the routing table does know is the part a caller gets wrong first — which
 * of the four principals a route authenticates, which permission it demands, and
 * which of them are open. That is what this writes down, alongside the response
 * envelope, which is uniform across every endpoint. Where the request body is
 * unknown it says so rather than inventing a schema.
 */
final class OpenApiGenerator
{
    /** Middleware that identifies the caller, and what it identifies them as. */
    private const PRINCIPALS = [
        'auth.admin' => ['adminToken', 'A company administrator, by Firebase ID token.'],
        'auth.employee' => ['employeeToken', 'An employee, by the token issued at sign-in.'],
        'auth.either' => ['employeeToken', 'Either an employee or an administrator.'],
        'auth.kiosk' => ['kioskToken', 'A paired kiosk tablet, which authenticates as a branch rather than a person.'],
        'auth.super' => ['superAdminToken', 'The support desk. Not scoped to a company.'],
        'auth.cron' => ['cronSecret', 'A scheduled job, by shared secret in the query string.'],
    ];

    /**
     * @return array<string, mixed>
     */
    public function generate(): array
    {
        $paths = [];
        $used = [];

        foreach ($this->routes() as $route) {
            $path = '/'.ltrim($route->uri(), '/');

            /** @var list<string> $methods */
            $methods = $route->methods();

            foreach ($methods as $method) {
                if (in_array($method, ['HEAD', 'OPTIONS'], true)) {
                    continue;
                }

                $operation = $this->operation($route, $method);
                $id = Value::string($operation['operationId']);

                // operationId has to be unique across the document, and a route
                // answering several verbs shares one name. The terminal endpoint
                // answers five.
                if (isset($used[$id])) {
                    $id .= '.'.strtolower($method);
                }

                $used[$id] = true;
                $operation['operationId'] = $id;

                $paths[$path][strtolower($method)] = $operation;
            }
        }

        ksort($paths);

        return [
            'openapi' => '3.1.0',
            'info' => [
                'title' => 'Permedjat API',
                'version' => '1',
                'description' => trim('
Attendance, payroll, leave and documents for a multi-tenant HR system.

Every response carries the same envelope. A success is `{"status":"success","data":…}`.
A refusal is `{"status":"fail","code":…,"message":…,"error_code":…}`, where `error_code`
is the stable key to branch on — `message` is prose and is translated.

`Accept-Language: ar` or `en` chooses the language of `message`. Anything else
falls back to the server default.

Writes are POST unless they replace or remove an addressable resource, which are
PATCH and DELETE. POST on an action path (`/approve`, `/terminate`) is not an
oversight: those are actions, not resource mutations.
                '),
            ],
            'servers' => [['url' => 'https://api.permedjat.com', 'description' => 'Production']],
            'components' => [
                'securitySchemes' => [
                    'adminToken' => ['type' => 'apiKey', 'in' => 'header', 'name' => 'X-Firebase-Token'],
                    'employeeToken' => ['type' => 'apiKey', 'in' => 'header', 'name' => 'X-Employee-Token'],
                    'kioskToken' => ['type' => 'apiKey', 'in' => 'header', 'name' => 'X-Kiosk-Token'],
                    'superAdminToken' => ['type' => 'http', 'scheme' => 'bearer'],
                    'cronSecret' => ['type' => 'apiKey', 'in' => 'query', 'name' => 'key'],
                ],
                'schemas' => [
                    'Success' => [
                        'type' => 'object',
                        'required' => ['status'],
                        'properties' => [
                            'status' => ['type' => 'string', 'const' => 'success'],
                            'data' => ['description' => 'Shape depends on the endpoint.'],
                            'data_source' => ['type' => 'string', 'description' => 'Set where a reply may come from a cache.'],
                        ],
                    ],
                    'Failure' => [
                        'type' => 'object',
                        'required' => ['status', 'code', 'message'],
                        'properties' => [
                            'status' => ['type' => 'string', 'enum' => ['fail', 'error']],
                            'code' => ['type' => 'integer', 'description' => 'Repeats the HTTP status in the body.'],
                            'message' => ['type' => 'string', 'description' => 'Prose, in the requested language. Do not branch on it.'],
                            'error_code' => ['type' => 'string', 'description' => 'Stable machine-readable key. Branch on this.'],
                            'meta' => ['type' => 'object', 'description' => 'Structured values the client formats itself.'],
                        ],
                    ],
                ],
            ],
            'paths' => $paths,
        ];
    }

    /**
     * @return list<Route>
     */
    private function routes(): array
    {
        $routes = [];

        /** @var list<Route> $all */
        $all = Router::getRoutes()->getRoutes();

        foreach ($all as $route) {
            $uri = $route->uri();

            // The framework's own health check and the storage passthrough are
            // not part of the API a client programs against.
            if (in_array($uri, ['up', 'storage/{path}'], true)) {
                continue;
            }

            $routes[] = $route;
        }

        return $routes;
    }

    /**
     * @return array<string, mixed>
     */
    private function operation(Route $route, string $method): array
    {
        $middleware = $route->gatherMiddleware();
        $op = [
            'operationId' => $route->getName() ?? Str::slug($method.'-'.$route->uri()) ?: strtolower($method).'-root',
            'tags' => [$this->tag($route)],
            'summary' => $this->summary($route),
            'responses' => [
                '200' => [
                    'description' => 'The call succeeded.',
                    'content' => ['application/json' => ['schema' => ['$ref' => '#/components/schemas/Success']]],
                ],
                '4XX' => [
                    'description' => 'Refused. Branch on error_code, not on message.',
                    'content' => ['application/json' => ['schema' => ['$ref' => '#/components/schemas/Failure']]],
                ],
            ],
        ];

        $parameters = [];

        foreach ($route->parameterNames() as $name) {
            $parameters[] = [
                'name' => $name,
                'in' => 'path',
                'required' => true,
                'schema' => ['type' => $name === 'id' ? 'integer' : 'string'],
            ];
        }

        $parameters[] = [
            'name' => 'Accept-Language',
            'in' => 'header',
            'required' => false,
            'description' => 'ar or en. Chooses the language of `message`.',
            'schema' => ['type' => 'string', 'enum' => ['ar', 'en']],
        ];

        $op['parameters'] = $parameters;

        if (in_array($method, ['POST', 'PATCH', 'PUT'], true)) {
            // Handlers read the body field by field rather than through a
            // request class, so there is nothing to derive a schema from.
            // Saying "an object" is true; inventing properties would not be.
            $op['requestBody'] = [
                'required' => false,
                'content' => ['application/json' => ['schema' => ['type' => 'object', 'additionalProperties' => true]]],
            ];
        }

        $security = [];

        foreach (self::PRINCIPALS as $alias => [$scheme, $_]) {
            if (in_array($alias, $middleware, true)) {
                $security[] = [$scheme => []];
            }
        }

        $op['security'] = $security;

        if ($security === []) {
            $op['description'] = 'Open: no principal is required.';
        }

        $permissions = [];

        foreach ($middleware as $m) {
            if (is_string($m) && str_starts_with($m, 'can.do:')) {
                $permissions[] = substr($m, 7);
            }
        }

        if ($permissions !== []) {
            // "a|b" in the middleware argument means any one of them is enough.
            $op['x-required-permission'] = implode(' or ', array_map(
                static fn (string $p): string => str_replace('|', ' or ', $p),
                $permissions,
            ));
        }

        if (in_array('app.secret', $middleware, true)) {
            $op['x-app-secret'] = 'Also gated by the client secret, sent as HTTP Basic.';
        }

        return $op;
    }

    private function tag(Route $route): string
    {
        $action = $route->getActionName();

        if (preg_match('#App\\\\Modules\\\\([A-Za-z]+)\\\\#', $action, $m) === 1) {
            return $m[1];
        }

        return 'Other';
    }

    /**
     * The first sentence of the handler's docblock, which is the closest thing
     * to a summary that already exists and is kept honest by sitting next to
     * the code it describes.
     *
     * Lines naming the PHP file a handler was ported from are skipped. They are
     * useful to us and meaningless to anyone reading the API.
     */
    private function summary(Route $route): string
    {
        $action = $route->getActionName();
        [$class, $method] = array_pad(explode('@', $action), 2, '__invoke');

        if (! class_exists($class)) {
            return '';
        }

        try {
            $reflection = new ReflectionClass($class);
            $doc = $reflection->hasMethod($method)
                ? ($reflection->getMethod($method)->getDocComment() ?: $reflection->getDocComment())
                : $reflection->getDocComment();
        } catch (ReflectionException) {
            return '';
        }

        if (! is_string($doc)) {
            return '';
        }

        foreach (explode("\n", $doc) as $line) {
            $line = trim(trim(trim($line), '/'), '* ');
            $line = trim(preg_replace('#\*/$#', '', $line) ?? $line);

            if ($line === '' || str_starts_with($line, '@')) {
                continue;
            }

            if (preg_match('/^Ports? of /', $line) === 1) {
                continue;
            }

            return $line;
        }

        return '';
    }
}
