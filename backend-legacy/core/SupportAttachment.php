<?php

/**
 * Attachments on support messages.
 *
 * `support_messages.attachment_url` / `attachment_name` have existed since the
 * ticketing system was built and nothing has ever written to them — a client
 * describing a bug could only describe it in words, and we could only answer in
 * words. Both sides can now attach a screenshot.
 *
 * Uploads arrive base64-encoded inside the JSON body (the same shape as face
 * enrollment) rather than as multipart, so every existing client — the Flutter
 * apps and the web app alike — can send one without a new transport.
 *
 * Nothing here trusts the caller's filename or claimed type: the extension is
 * derived from the bytes, and the stored name is generated.
 */
final class SupportAttachment {
    /** A screenshot or a short PDF. Anything larger is not a support attachment. */
    private const MAX_BYTES = 5 * 1024 * 1024;

    private const IMAGE_EXTENSIONS = [
        IMAGETYPE_JPEG => 'jpg',
        IMAGETYPE_PNG => 'png',
        IMAGETYPE_GIF => 'gif',
        IMAGETYPE_WEBP => 'webp',
    ];

    /**
     * Decode and store one attachment.
     *
     * @return array{path: string, name: string}|null null when there is nothing
     *         usable to store; the caller keeps the message either way — losing
     *         the text because the image was odd would be the worse failure.
     */
    public static function store($base64, int $ticketId, ?string $originalName = null): ?array {
        if (!is_string($base64) || $base64 === '') {
            return null;
        }

        try {
            $data = base64_decode(preg_replace('#^data:[^;]+;base64,#i', '', $base64), true);
            if ($data === false || $data === '' || strlen($data) > self::MAX_BYTES) {
                return null;
            }

            $extension = self::extensionFor($data);
            if ($extension === null) {
                return null;
            }

            $dir = __DIR__ . '/../uploads/support/';
            if (!is_dir($dir) && !mkdir($dir, 0755, true) && !is_dir($dir)) {
                return null;
            }

            $name = 'ticket_' . $ticketId . '_' . time() . '_' . bin2hex(random_bytes(4)) . '.' . $extension;
            if (file_put_contents($dir . $name, $data) === false) {
                return null;
            }

            // The display name is the caller's, sanitised; the stored name is ours.
            $display = trim((string) $originalName);
            $display = $display === ''
                ? ('attachment.' . $extension)
                : mb_substr(preg_replace('#[/\\\\\r\n]+#', '_', $display), 0, 255);

            return ['path' => 'uploads/support/' . $name, 'name' => $display];
        } catch (Exception $e) {
            error_log('Support attachment failed: ' . $e->getMessage());
            return null;
        }
    }

    /** Absolute path of a stored attachment, or null if it is not one of ours. */
    public static function resolve(?string $storedPath): ?string {
        if (!is_string($storedPath) || $storedPath === '') {
            return null;
        }
        // Only ever serve out of uploads/support/, whatever the column says.
        if (strpos($storedPath, 'uploads/support/') !== 0 || strpos($storedPath, '..') !== false) {
            return null;
        }
        $full = __DIR__ . '/../' . $storedPath;
        return is_file($full) ? $full : null;
    }

    public static function mimeFor(string $absolutePath): string {
        $extension = strtolower(pathinfo($absolutePath, PATHINFO_EXTENSION));
        $map = [
            'jpg' => 'image/jpeg',
            'jpeg' => 'image/jpeg',
            'png' => 'image/png',
            'gif' => 'image/gif',
            'webp' => 'image/webp',
            'pdf' => 'application/pdf',
        ];
        return $map[$extension] ?? 'application/octet-stream';
    }

    /** Extension inferred from the bytes themselves, never from the filename. */
    private static function extensionFor(string $data): ?string {
        $info = @getimagesizefromstring($data);
        if ($info !== false && isset(self::IMAGE_EXTENSIONS[$info[2]])) {
            return self::IMAGE_EXTENSIONS[$info[2]];
        }
        if (strncmp($data, '%PDF-', 5) === 0) {
            return 'pdf';
        }
        return null;
    }
}
