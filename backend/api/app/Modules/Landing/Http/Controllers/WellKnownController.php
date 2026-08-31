<?php

declare(strict_types=1);

namespace App\Modules\Landing\Http\Controllers;

use App\Exceptions\ApiFailure;
use Illuminate\Http\Request;
use Illuminate\Http\Response;

/**
 * The deep-link association files.
 *
 * Android and iOS fetch these from a fixed path to decide whether a domain may
 * open an app. Static content, but served through the app for two reasons the
 * old backend also had: the Apple file has no extension and must still come
 * back as JSON, and a blanket "deny *.json" rule in the web server would
 * otherwise 403 the Android one.
 *
 * There are two pairs, because there are two apps claiming two domains. The
 * employee app declares medjatapp.com; the management app declares
 * api.medjatapp.com. Serving the wrong pair does not fail loudly — the link
 * just opens a web page instead of the app, which looks exactly like the app
 * not being installed.
 *
 * The pair is chosen by the host asked, rather than fixed per deployment, so
 * one running app answers correctly on whichever domain reaches it.
 */
final class WellKnownController
{
    /**
     * host prefix => [android file, apple file]
     *
     * @var array<string, array{0: string, 1: string}>
     */
    private const PAIRS = [
        // The management app.
        'api' => ['assetlinks-central.json', 'apple-app-site-association-central'],
        // The employee app, on the bare domain.
        'default' => ['assetlinks.json', 'apple-app-site-association'],
    ];

    public function __invoke(Request $request, string $file): Response
    {
        [$android, $apple] = self::PAIRS[$this->pairFor($request)];

        $name = match ($file) {
            'assetlinks.json' => $android,
            'apple-app-site-association' => $apple,
            default => null,
        };

        if ($name === null) {
            throw new ApiFailure('Not found', 404, 'not_found');
        }

        $path = resource_path('well-known/'.$name);

        if (! is_file($path)) {
            throw new ApiFailure('Not found', 404, 'not_found');
        }

        $contents = file_get_contents($path);

        return new Response($contents === false ? '' : $contents, 200, [
            // Both files, the extension-less Apple one included: the OS refuses
            // anything that is not JSON.
            'Content-Type' => 'application/json',
            'Cache-Control' => 'public, max-age=3600',
        ]);
    }

    private function pairFor(Request $request): string
    {
        return str_starts_with($request->getHost(), 'api.') ? 'api' : 'default';
    }
}
