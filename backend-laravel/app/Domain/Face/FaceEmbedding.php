<?php

declare(strict_types=1);

namespace App\Domain\Face;

/**
 * A face embedding: the vector the phone extracts from a selfie.
 *
 * The image itself never reaches the server on the matching path — only these
 * numbers — which is why the comparison lives here and the verdict is computed
 * on the server rather than reported by the client.
 */
final class FaceEmbedding
{
    /** The model the shipped app uses. A stored vector from another one cannot be compared. */
    public const MODEL_VERSION = 'mobilefacenet_v1';

    /** MobileFaceNet emits 192, FaceNet 128; 512 covers the larger variants. */
    private const ALLOWED_DIMENSIONS = [128, 192, 512];

    /**
     * Parses and validates a client-supplied vector.
     *
     * @return list<float>|null Null when the payload is not a usable vector.
     */
    public static function parse(mixed $raw): ?array
    {
        if (is_string($raw)) {
            $raw = json_decode($raw, true);
        }

        if (! is_array($raw) || ! in_array(count($raw), self::ALLOWED_DIMENSIONS, true)) {
            return null;
        }

        $vector = [];
        foreach ($raw as $value) {
            if (! is_numeric($value)) {
                return null;
            }

            $float = (float) $value;

            // NAN and INF would poison the arithmetic below and score as a
            // perfect match against anything.
            if (! is_finite($float)) {
                return null;
            }

            $vector[] = $float;
        }

        return $vector;
    }

    /**
     * Cosine similarity, in [-1, 1] — in practice [0, 1] for face embeddings.
     *
     * @param  list<float>  $a
     * @param  list<float>  $b
     */
    public static function similarity(array $a, array $b): float
    {
        if ($a === [] || count($a) !== count($b)) {
            return 0.0;
        }

        $dot = 0.0;
        $normA = 0.0;
        $normB = 0.0;

        foreach ($a as $i => $valueA) {
            $valueB = $b[$i];
            $dot += $valueA * $valueB;
            $normA += $valueA ** 2;
            $normB += $valueB ** 2;
        }

        if ($normA <= 0.0 || $normB <= 0.0) {
            return 0.0;
        }

        return $dot / (sqrt($normA) * sqrt($normB));
    }

    /**
     * A stable fingerprint of the exact numbers submitted.
     *
     * Used to spot an embedding sent twice. The server never sees the image, so
     * it cannot tell a camera capture from an array read out of storage — but a
     * real face never produces the same numbers twice, because lighting, head
     * angle and distance all move. Identical numbers were replayed, not
     * captured.
     *
     * @param  list<float>  $embedding
     */
    public static function fingerprint(array $embedding): string
    {
        // Rounded before hashing so floating-point noise in transport does not
        // make two genuinely identical payloads look different.
        $rounded = array_map(static fn (float $v): string => number_format($v, 6, '.', ''), $embedding);

        return hash('sha256', implode(',', $rounded));
    }
}
