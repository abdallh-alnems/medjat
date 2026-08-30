<?php

declare(strict_types=1);

namespace App\Shared\Face;

/**
 * The outcome of one selfie attempt.
 */
final readonly class FaceVerification
{
    public function __construct(
        public bool $accepted,
        public string $result,
        public ?float $score,
        public float $threshold,
        public string $message,
    ) {}

    public static function refuse(string $result, float $threshold, string $message, ?float $score = null): self
    {
        return new self(false, $result, $score, $threshold, $message);
    }

    public static function accept(string $result, float $threshold, float $score): self
    {
        return new self(true, $result, $score, $threshold, '');
    }
}
