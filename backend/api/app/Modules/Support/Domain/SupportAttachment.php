<?php

declare(strict_types=1);

namespace App\Modules\Support\Domain;

use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Throwable;

/**
 * A screenshot or document attached to a support message.
 *
 * Storage never refuses the message: an odd image comes back as null and the
 * text is kept anyway. Losing what somebody wrote because the picture was
 * strange would be the worse failure by far.
 */
final class SupportAttachment
{
    private const MAX_BYTES = 5 * 1024 * 1024;

    /** @var array<int, string> */
    private const IMAGE_EXTENSIONS = [
        IMAGETYPE_JPEG => 'jpg',
        IMAGETYPE_PNG => 'png',
        IMAGETYPE_GIF => 'gif',
        IMAGETYPE_WEBP => 'webp',
    ];

    /** @var array<string, string> */
    private const MIME_TYPES = [
        'jpg' => 'image/jpeg',
        'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        'pdf' => 'application/pdf',
    ];

    /**
     * @return array{path: string, name: string}|null
     */
    public static function store(mixed $base64, int $ticketId, ?string $originalName = null): ?array
    {
        if (! is_string($base64) || $base64 === '') {
            return null;
        }

        try {
            $stripped = preg_replace('#^data:[^;]+;base64,#i', '', $base64) ?? $base64;
            $data = base64_decode($stripped, true);

            if ($data === false || $data === '' || strlen($data) > self::MAX_BYTES) {
                return null;
            }

            $extension = self::extensionFor($data);

            if ($extension === null) {
                return null;
            }

            $name = sprintf('ticket_%d_%d_%s.%s', $ticketId, time(), bin2hex(random_bytes(4)), $extension);
            Storage::disk('uploads')->put('support/'.$name, $data);

            // The display name is the caller's, sanitised; the stored name is
            // ours, so a filename can never become a path.
            $display = trim($originalName ?? '');
            $display = $display === ''
                ? 'attachment.'.$extension
                : mb_substr(preg_replace('#[/\\\\\r\n]+#', '_', $display) ?? $display, 0, 255);

            return ['path' => 'uploads/support/'.$name, 'name' => $display];
        } catch (Throwable $e) {
            Log::warning('Support attachment failed', ['ticket_id' => $ticketId, 'exception' => $e]);

            return null;
        }
    }

    /**
     * The path relative to the uploads disk, or null if it is not one of ours.
     *
     * Only ever serves out of the support directory, whatever the column says.
     */
    public static function relativePath(?string $storedPath): ?string
    {
        if ($storedPath === null || $storedPath === '') {
            return null;
        }

        if (! str_starts_with($storedPath, 'uploads/support/') || str_contains($storedPath, '..')) {
            return null;
        }

        return substr($storedPath, strlen('uploads/'));
    }

    public static function mimeFor(string $path): string
    {
        return self::MIME_TYPES[strtolower(pathinfo($path, PATHINFO_EXTENSION))] ?? 'application/octet-stream';
    }

    /**
     * Judged from the bytes, never from the name a client supplied.
     */
    private static function extensionFor(string $data): ?string
    {
        $image = @getimagesizefromstring($data);

        if ($image !== false && isset(self::IMAGE_EXTENSIONS[$image[2]])) {
            return self::IMAGE_EXTENSIONS[$image[2]];
        }

        return str_starts_with($data, '%PDF-') ? 'pdf' : null;
    }
}
