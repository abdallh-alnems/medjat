<?php

require_once __DIR__ . '/FaceMatchService.php';

/**
 * One-to-many face identification for a branch kiosk.
 *
 * **This is the riskiest code in the feature.** Everything else follows a
 * pattern that already exists somewhere in this codebase; this does not.
 *
 * `FaceMatchService::verify()` answers "is this Ahmed?" — one known person, one
 * threshold. A kiosk has to answer "who is this?" against the whole branch
 * roster, and that is not the same problem with a loop around it. False accepts
 * compound: at a per-comparison false-accept rate of p, scanning N candidates
 * gives roughly `1 - (1-p)^N`. With the 0.450 threshold FaceMatchService ships
 * for 1:1, and the measured FAR of 0.2% behind it, a 200-person branch is about
 * a **one-in-three** chance of attributing a punch to the wrong person.
 *
 * Raising the threshold alone does not fix it — it trades false accepts for a
 * rejection rate that makes the kiosk unusable. What fixes it is the **margin
 * rule**: the best candidate must not only clear the threshold, it must beat
 * the runner-up by a gap. That filters exactly the failure mode that matters —
 * a capture that resembles several enrolled people — and lets an ambiguous
 * capture fall through to the personal code instead of being silently assigned
 * to whoever happened to score highest.
 *
 * Cost is not a concern. 200 candidates x 192 floats is microseconds; there is
 * no vector index here because there is no performance problem here. The
 * problem is entirely statistical.
 *
 * The starting operating point (0.550 / 0.080) is derived from LFW pairs, NOT
 * from a branch. It is a hypothesis to be tuned from `station_recognition_logs`,
 * which is why every attempt records the runner-up and the candidate count.
 */
final class KioskIdentifier {
    /**
     * Stricter than FaceMatchService::DEFAULT_THRESHOLD (0.450), which was
     * chosen for 1:1 verification and is unsafe across a roster.
     */
    public const DEFAULT_THRESHOLD = 0.550;

    /** Required gap between the best and second-best candidate. */
    public const DEFAULT_MARGIN = 0.080;

    /**
     * Roster size beyond which this design cannot hold the target
     * mis-attribution rate at any threshold. Surfaced as a warning rather than
     * a hard block: refusing to serve a branch that grew is worse than telling
     * its administrator that face-only identification is past its limit.
     */
    public const ROSTER_WARN_ABOVE = 150;

    /**
     * Resolves the effective matching parameters for a branch.
     *
     * @return array{threshold: float, margin: float}
     */
    public static function settingsFor(?array $branch): array {
        $threshold = ($branch['station_match_threshold'] ?? null) !== null
            ? (float) $branch['station_match_threshold']
            : self::DEFAULT_THRESHOLD;

        $margin = ($branch['station_match_margin'] ?? null) !== null
            ? (float) $branch['station_match_margin']
            : self::DEFAULT_MARGIN;

        return ['threshold' => $threshold, 'margin' => $margin];
    }

    /**
     * The enrolled candidates a kiosk may match against.
     *
     * Scoped to the station's branch and to employees who are not terminated —
     * both server-side, so a tablet cannot widen its own search. Model version
     * is filtered here rather than compared per-candidate: an embedding from a
     * different model lives in a different space, and comparing across them
     * produces numbers that look plausible and mean nothing.
     */
    public static function candidatesFor(int $tenantId, int $branchId, string $modelVersion): array {
        return Database::fetchAll(
            "SELECT id, name, face_embedding, face_embedding_dim
               FROM employees
              WHERE tenant_id = ?
                AND branch_id = ?
                AND status <> 'terminated'
                AND face_embedding IS NOT NULL
                AND face_model_version = ?",
            [$tenantId, $branchId, $modelVersion]
        );
    }

    /**
     * Scores a probe against every candidate and applies threshold + margin.
     *
     * Returns the decision rather than responding, so the caller decides what
     * it means for its own flow (a punch, an enrollment guard, a log_only
     * observation).
     *
     * @param array $probe      The embedding extracted on the tablet.
     * @param array $candidates Rows from candidatesFor().
     *
     * @return array{
     *   outcome: string, employee_id: ?int, employee_name: ?string,
     *   score: ?float, runner_up: ?float, candidates: int,
     *   threshold: float, margin: float
     * }
     */
    public static function identify(array $probe, array $candidates, float $threshold, float $margin): array {
        $result = [
            'outcome'       => 'no_match',
            'employee_id'   => null,
            'employee_name' => null,
            'score'         => null,
            'runner_up'     => null,
            'candidates'    => count($candidates),
            'threshold'     => $threshold,
            'margin'        => $margin,
        ];

        if (empty($candidates)) {
            return $result;
        }

        $bestScore = -1.0;
        $bestRow   = null;
        $secondScore = -1.0;

        foreach ($candidates as $row) {
            $vector = FaceMatchService::parseEmbedding($row['face_embedding']);
            if ($vector === null || count($vector) !== count($probe)) {
                // A stored embedding of the wrong shape is skipped rather than
                // scored as 0: a zero would quietly widen the margin and make
                // an ambiguous capture look decisive.
                $result['candidates']--;
                continue;
            }

            $score = FaceMatchService::similarity($probe, $vector);

            if ($score > $bestScore) {
                $secondScore = $bestScore;
                $bestScore = $score;
                $bestRow = $row;
            } elseif ($score > $secondScore) {
                $secondScore = $score;
            }
        }

        if ($bestRow === null) {
            return $result;
        }

        $result['score']     = round($bestScore, 3);
        $result['runner_up'] = $secondScore >= 0 ? round($secondScore, 3) : null;

        if ($bestScore < $threshold) {
            $result['outcome'] = 'no_match';
            return $result;
        }

        // The margin rule. With a single enrolled candidate there is no
        // runner-up to compare against, and the threshold alone decides — that
        // is correct, not a gap: a one-person branch has no ambiguity to
        // resolve.
        if ($secondScore >= 0 && ($bestScore - $secondScore) < $margin) {
            $result['outcome'] = 'ambiguous';
            return $result;
        }

        $result['outcome']       = 'matched';
        $result['employee_id']   = (int) $bestRow['id'];
        $result['employee_name'] = $bestRow['name'];

        return $result;
    }
}
