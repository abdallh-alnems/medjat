<?php

declare(strict_types=1);

namespace App\Modules\Attendance\Domain;

use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Throwable;

/**
 * Stores the evidence image captured at a punch.
 *
 * Returns the stored path, or null when there is nothing usable — the caller
 * decides whether that is fatal, because two different rules can demand a photo
 * and only one of them is about this method.
 */
final class PunchPhotoStore
{
    private const SUBDIR = 'attendance';

    /** Roughly a high-quality phone selfie. Larger is a mistake or an attack. */
    private const MAX_BYTES = 3_000_000;

    public static function store(?string $imageBase64, int $tenantId, int $employeeId): ?string
    {
        if (! is_string($imageBase64) || $imageBase64 === '') {
            return null;
        }

        try {
            $payload = preg_replace('#^data:image/\w+;base64,#i', '', $imageBase64) ?? '';
            $data = base64_decode($payload, true);

            if ($data === false || $data === '' || strlen($data) > self::MAX_BYTES) {
                return null;
            }

            // Confirm it really is an image before writing it under a .jpg name.
            // Without this the endpoint is an arbitrary-file-upload primitive
            // wearing an image extension.
            if (@getimagesizefromstring($data) === false) {
                return null;
            }

            $name = sprintf(
                '%s/punch_%d_%d_%d_%s.jpg',
                self::SUBDIR,
                $tenantId,
                $employeeId,
                time(),
                bin2hex(random_bytes(4)),
            );

            // The uploads disk is served only through an authenticated endpoint;
            // nothing written here is reachable by URL. These are photographs of
            // employees at work.
            Storage::disk('uploads')->put($name, $data);

            return $name;
        } catch (Throwable $e) {
            Log::error('Punch photo could not be stored', ['tenant_id' => $tenantId, 'exception' => $e]);

            return null;
        }
    }
}
