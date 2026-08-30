<?php

declare(strict_types=1);

namespace App\Http;

use Illuminate\Http\JsonResponse;

/**
 * The wire format of the Medjat API.
 *
 * Four Flutter builds already published to Google Play, the App Store and
 * AppGallery parse these envelopes field by field, so the shape is a contract,
 * not a preference: `status` is one of success/fail/error, `code` repeats the
 * HTTP status in the body, and `error_code` is the stable machine-readable key
 * the apps branch on. Adding a field is safe; renaming or dropping one breaks
 * installs that cannot be updated on our schedule.
 *
 * JSON_UNESCAPED_UNICODE is not cosmetic either — the apps and the Arabic UI
 * expect readable Arabic, and Laravel would otherwise emit \uXXXX escapes.
 */
final class ApiResponse
{
    private const JSON_FLAGS = JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES;

    public static function success(mixed $data = null, int $code = 200, ?string $source = null): JsonResponse
    {
        $payload = ['status' => 'success'];

        if ($source !== null) {
            $payload['data_source'] = $source;
        }
        if ($data !== null) {
            $payload['data'] = $data;
        }

        return self::json($payload, $code);
    }

    /**
     * A request that reached the application and was refused by it — bad input,
     * an expired session, a permission the caller does not hold.
     *
     * @param  array<string, mixed>|null  $meta  Structured values the client
     *                                           localizes itself (remaining days,
     *                                           limits) rather than showing our
     *                                           server-side Arabic string.
     */
    public static function fail(string $message, int $code = 400, ?string $errorCode = null, ?array $meta = null): JsonResponse
    {
        $payload = [
            'status' => 'fail',
            'code' => $code,
            'message' => $message,
        ];

        if ($errorCode !== null) {
            $payload['error_code'] = $errorCode;
        }
        if ($meta !== null) {
            $payload['meta'] = $meta;
        }

        return self::json($payload, $code);
    }

    /**
     * A fault on our side. Kept distinct from fail() because the apps treat it
     * as retryable and it is the one that belongs in the log.
     *
     * @param  array<string, mixed>|null  $details
     */
    public static function error(string $message, int $code = 500, ?array $details = null): JsonResponse
    {
        $payload = [
            'status' => 'error',
            'code' => $code,
            'message' => $message,
        ];

        if ($details !== null) {
            $payload['details'] = $details;
        }

        return self::json($payload, $code);
    }

    /**
     * @param  array<string, mixed>  $payload
     */
    private static function json(array $payload, int $code): JsonResponse
    {
        return new JsonResponse($payload, $code, [], self::JSON_FLAGS);
    }
}
