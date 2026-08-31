<?php

declare(strict_types=1);

namespace App\Shared\Face;

use Illuminate\Support\Facades\DB;

/**
 * Carries one attempt's audit fields so they are not threaded through six
 * signatures. Every branch above writes exactly one row, including the ones that
 * refuse — an attempt nobody recorded is an attempt nobody can review.
 */
final class FaceLogContext
{
    public ?string $fingerprint = null;

    /**
     * @param  array<array-key, mixed>  $input
     */
    public function __construct(
        private readonly int $tenantId,
        private readonly int $employeeId,
        private readonly ?int $branchId,
        private readonly string $purpose,
        private readonly float $threshold,
        private readonly ?float $latitude,
        private readonly ?float $longitude,
        /** @var array<array-key, mixed> */
        private readonly array $input,
    ) {}

    public function write(
        string $result,
        bool $accepted,
        ?float $score,
        bool $livenessPassed,
        ?string $challenge,
        ?string $selfiePath,
    ): void {
        DB::table('face_verification_logs')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'branch_id' => $this->branchId,
            'purpose' => $this->purpose,
            'result' => $result,
            'accepted' => $accepted ? 1 : 0,
            'match_score' => $score,
            'threshold' => $this->threshold,
            'liveness_passed' => $livenessPassed ? 1 : 0,
            'challenge' => $challenge,
            'latitude' => $this->latitude,
            'longitude' => $this->longitude,
            'selfie_path' => $selfiePath,
            // Client-reported, so useful for triage and worthless as proof.
            'is_mock_location' => empty($this->input['is_mock_location']) ? 0 : 1,
            'is_rooted_device' => empty($this->input['is_rooted_device']) ? 0 : 1,
            'embedding_hash' => $this->fingerprint,
        ]);
    }
}
