<?php

declare(strict_types=1);

namespace App\Shared\Face;

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
        // Quantised first — but not for the reason it looks like.
        //
        // Rounding does NOT defeat an attacker who adds noise. Perturbing every
        // component by 1e-6 changes the fingerprint, because with 192
        // components some inevitably sit near a rounding boundary and flip.
        // Anyone deliberately jittering the array evades this, and no amount of
        // quantisation fixes it: a hash answers "identical", never "similar".
        //
        // What it buys is representation stability. The same capture arrives as
        // a float, or a string, or through a JSON round trip, and 0.1 printed
        // at full precision is not always the same text. Without rounding an
        // honest replay could hash differently and slip past — a false
        // negative, which is the failure that matters for a detector.
        //
        // sprintf rather than round()+implode: locale-independent (a decimal
        // comma would silently change every hash) and it gives -0.0 and 0.0 the
        // same text, which they should have.
        //
        // The honest scope: this catches a build that stores an embedding and
        // posts it back verbatim, which is what a modified APK does. It does not
        // catch someone editing float arrays.
        $quantised = array_map(static fn (float $v): string => sprintf('%.4F', $v), $embedding);

        return hash('sha256', implode(',', $quantised));
    }
}
