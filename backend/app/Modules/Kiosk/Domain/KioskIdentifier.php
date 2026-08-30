<?php

declare(strict_types=1);

namespace App\Modules\Kiosk\Domain;

use App\Models\Branch;
use App\Shared\Face\FaceEmbedding;
use App\Support\Value;
use Illuminate\Support\Facades\DB;

/**
 * One-to-many face identification for a branch kiosk.
 *
 * This is the riskiest code in the feature. Verification answers "is this
 * Ahmed?" — one known person, one threshold. A kiosk has to answer "who is
 * this?" against the whole branch roster, and that is not the same problem with
 * a loop around it. False accepts compound: at a per-comparison false-accept
 * rate of p, scanning N candidates gives roughly 1 - (1-p)^N. At the 0.450
 * threshold the one-to-one path ships with, and the 0.2% false-accept rate
 * measured behind it, a 200-person branch is about a one-in-three chance of
 * attributing a punch to the wrong person.
 *
 * Raising the threshold alone does not fix that — it trades false accepts for a
 * rejection rate that makes the kiosk unusable. What fixes it is the margin
 * rule: the best candidate must not only clear the threshold, it must beat the
 * runner-up by a gap. That filters exactly the failure mode that matters — a
 * capture resembling several enrolled people — and lets an ambiguous capture
 * fall through to the personal code instead of being assigned to whoever
 * happened to score highest.
 *
 * Cost is not a concern: 200 candidates by 192 floats is microseconds. There is
 * no vector index here because there is no performance problem here. The
 * problem is entirely statistical.
 */
final class KioskIdentifier
{
    /**
     * Stricter than the one-to-one default, which was chosen for verification
     * and is unsafe across a roster.
     */
    public const DEFAULT_THRESHOLD = 0.550;

    /** Required gap between the best and second-best candidate. */
    public const DEFAULT_MARGIN = 0.080;

    /**
     * Roster size beyond which this design cannot hold the target
     * mis-attribution rate at any threshold. A warning rather than a block:
     * refusing to serve a branch that grew is worse than telling its
     * administrator that face-only identification has reached its limit.
     */
    public const ROSTER_WARN_ABOVE = 150;

    /**
     * @return array{threshold: float, margin: float}
     */
    public static function settingsFor(?Branch $branch): array
    {
        $threshold = $branch?->getAttribute('station_match_threshold');
        $margin = $branch?->getAttribute('station_match_margin');

        return [
            'threshold' => is_numeric($threshold) ? (float) $threshold : self::DEFAULT_THRESHOLD,
            'margin' => is_numeric($margin) ? (float) $margin : self::DEFAULT_MARGIN,
        ];
    }

    /**
     * The enrolled candidates a kiosk may match against.
     *
     * Scoped to the station's branch and to people who still work there, both
     * server-side, so a tablet cannot widen its own search. Model version is
     * filtered here rather than compared per candidate: an embedding from a
     * different model lives in a different space, and comparing across them
     * produces numbers that look plausible and mean nothing.
     *
     * @return list<array<string, mixed>>
     */
    public static function candidatesFor(int $tenantId, int $branchId, string $modelVersion): array
    {
        $rows = DB::table('employees')
            ->where('tenant_id', $tenantId)
            ->where('branch_id', $branchId)
            ->where('status', '!=', 'terminated')
            ->whereNotNull('face_embedding')
            ->where('face_model_version', $modelVersion)
            ->get(['id', 'name', 'face_embedding', 'face_embedding_dim'])
            ->all();

        return array_values(array_map(
            static function (mixed $row): array {
                /** @var array<string, mixed> $columns */
                $columns = (array) $row;

                return $columns;
            },
            $rows,
        ));
    }

    /**
     * Scores a probe against every candidate and applies threshold and margin.
     *
     * Returns the decision rather than responding, so the caller decides what it
     * means for its own flow — a punch, an enrollment guard, a log-only
     * observation.
     *
     * @param  list<float>  $probe  The embedding extracted on the tablet.
     * @param  list<array<string, mixed>>  $candidates
     * @return array{outcome: string, employee_id: int|null, employee_name: string|null, score: float|null, runner_up: float|null, candidates: int, threshold: float, margin: float}
     */
    public static function identify(array $probe, array $candidates, float $threshold, float $margin): array
    {
        $result = [
            'outcome' => 'no_match',
            'employee_id' => null,
            'employee_name' => null,
            'score' => null,
            'runner_up' => null,
            'candidates' => count($candidates),
            'threshold' => $threshold,
            'margin' => $margin,
        ];

        if ($candidates === []) {
            return $result;
        }

        $bestScore = -1.0;
        $secondScore = -1.0;
        $best = null;

        foreach ($candidates as $candidate) {
            $vector = FaceEmbedding::parse($candidate['face_embedding'] ?? null);

            if ($vector === null || count($vector) !== count($probe)) {
                // A stored embedding of the wrong shape is skipped rather than
                // scored as zero: a zero would quietly widen the margin and make
                // an ambiguous capture look decisive.
                $result['candidates']--;

                continue;
            }

            $score = FaceEmbedding::similarity($probe, $vector);

            if ($score > $bestScore) {
                $secondScore = $bestScore;
                $bestScore = $score;
                $best = $candidate;
            } elseif ($score > $secondScore) {
                $secondScore = $score;
            }
        }

        if ($best === null) {
            return $result;
        }

        $result['score'] = round($bestScore, 3);
        $result['runner_up'] = $secondScore >= 0 ? round($secondScore, 3) : null;

        if ($bestScore < $threshold) {
            return $result;
        }

        // With a single enrolled candidate there is no runner-up and the
        // threshold alone decides. That is correct rather than a gap: a
        // one-person branch has no ambiguity to resolve.
        if ($secondScore >= 0 && ($bestScore - $secondScore) < $margin) {
            $result['outcome'] = 'ambiguous';

            return $result;
        }

        $result['outcome'] = 'matched';
        $result['employee_id'] = Value::int($best['id'] ?? null);
        $result['employee_name'] = Value::nullableString($best['name'] ?? null);

        return $result;
    }
}
