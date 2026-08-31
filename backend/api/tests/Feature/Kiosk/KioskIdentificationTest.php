<?php

declare(strict_types=1);

namespace Tests\Feature\Kiosk;

use App\Modules\Kiosk\Domain\KioskIdentifier;
use Tests\TestCase;

/**
 * One-to-many identification: the threshold, and the margin rule that makes it
 * safe across a roster.
 */
final class KioskIdentificationTest extends TestCase
{
    /** The real model's width; anything else is rejected before scoring. */
    private const DIMENSIONS = 128;

    /**
     * A unit vector pointing mostly along the first axis, tilted by $tilt.
     *
     * Two of these are similar when their tilts are close, which is what makes
     * a controlled near-twin possible without running a face model.
     *
     * @return list<float>
     */
    private static function vector(float $tilt): array
    {
        $out = [cos($tilt), sin($tilt)];

        while (count($out) < self::DIMENSIONS) {
            $out[] = 0.0;
        }

        return $out;
    }

    /**
     * @param  array<int, array{0: int, 1: string, 2: float}>  $people
     * @return list<array<string, mixed>>
     */
    private static function candidates(array $people): array
    {
        return array_values(array_map(static fn (array $p): array => [
            'id' => $p[0],
            'name' => $p[1],
            'face_embedding' => (string) json_encode(self::vector($p[2])),
            'face_embedding_dim' => self::DIMENSIONS,
        ], $people));
    }

    public function test_an_empty_roster_matches_nobody(): void
    {
        $result = KioskIdentifier::identify(self::vector(0.0), [], 0.55, 0.08);

        $this->assertSame('no_match', $result['outcome']);
        $this->assertSame(0, $result['candidates']);
        $this->assertNull($result['score']);
    }

    public function test_a_clear_match_is_returned_with_its_score(): void
    {
        $candidates = self::candidates([[7, 'Ahmed', 0.0], [8, 'Mona', 1.2]]);

        $result = KioskIdentifier::identify(self::vector(0.02), $candidates, 0.55, 0.08);

        $this->assertSame('matched', $result['outcome']);
        $this->assertSame(7, $result['employee_id']);
        $this->assertSame('Ahmed', $result['employee_name']);
        $this->assertGreaterThan(0.55, (float) $result['score']);
    }

    public function test_nobody_close_enough_is_no_match(): void
    {
        $candidates = self::candidates([[7, 'Ahmed', 1.4], [8, 'Mona', 1.5]]);

        $this->assertSame('no_match', KioskIdentifier::identify(self::vector(0.0), $candidates, 0.55, 0.08)['outcome']);
    }

    public function test_two_people_the_capture_resembles_equally_are_ambiguous(): void
    {
        // The failure mode the margin rule exists for. Without it the winner is
        // decided by a difference that is noise, not identification — and the
        // punch lands on whichever of them scored a fraction higher.
        $candidates = self::candidates([[7, 'Ahmed', 0.02], [8, 'Twin', 0.10]]);

        $result = KioskIdentifier::identify(self::vector(0.0), $candidates, 0.55, 0.20);

        $this->assertSame('ambiguous', $result['outcome']);
        $this->assertNull($result['employee_id']);
        // The runner-up travels with the decision, because tuning the margin
        // needs the gap that produced it.
        $this->assertNotNull($result['runner_up']);
    }

    public function test_the_same_pair_matches_once_the_margin_is_relaxed(): void
    {
        $candidates = self::candidates([[7, 'Ahmed', 0.02], [8, 'Twin', 0.10]]);

        // The two are 0.005 apart. A company that measured that gap on its own
        // data and set the margin below it gets a decision; the shipped 0.080
        // would not.
        $result = KioskIdentifier::identify(self::vector(0.0), $candidates, 0.55, 0.001);

        $this->assertSame('matched', $result['outcome']);
        $this->assertSame(7, $result['employee_id']);
    }

    public function test_one_enrolled_person_needs_no_margin(): void
    {
        // A one-person branch has no ambiguity to resolve, so the threshold
        // alone decides. That is correct rather than a gap in the rule.
        $candidates = self::candidates([[7, 'Ahmed', 0.0]]);

        $result = KioskIdentifier::identify(self::vector(0.01), $candidates, 0.55, 0.9);

        $this->assertSame('matched', $result['outcome']);
        $this->assertNull($result['runner_up']);
    }

    public function test_an_embedding_of_the_wrong_shape_is_skipped_not_scored(): void
    {
        // Scoring it as zero would quietly widen the margin and make an
        // ambiguous capture look decisive.
        $candidates = self::candidates([[7, 'Ahmed', 0.02], [8, 'Twin', 0.10]]);
        $candidates[1]['face_embedding'] = json_encode(array_fill(0, 512, 0.1));

        $result = KioskIdentifier::identify(self::vector(0.0), $candidates, 0.55, 0.20);

        $this->assertSame('matched', $result['outcome']);
        $this->assertSame(7, $result['employee_id']);
        // The count reports what was actually compared.
        $this->assertSame(1, $result['candidates']);
    }

    public function test_the_decision_carries_the_settings_it_was_made_under(): void
    {
        // Every attempt is logged with these so a company can tune from its own
        // data rather than the shipped guess.
        $result = KioskIdentifier::identify(self::vector(0.0), self::candidates([[7, 'A', 0.0]]), 0.61, 0.07);

        $this->assertSame(0.61, $result['threshold']);
        $this->assertSame(0.07, $result['margin']);
    }

    public function test_the_kiosk_default_is_stricter_than_one_to_one_verification(): void
    {
        // Chosen for verification, the 0.450 threshold is unsafe across a
        // roster: false accepts compound with every enrolled face.
        $this->assertGreaterThan(0.450, KioskIdentifier::DEFAULT_THRESHOLD);
        $this->assertGreaterThan(0.0, KioskIdentifier::DEFAULT_MARGIN);
    }
}
