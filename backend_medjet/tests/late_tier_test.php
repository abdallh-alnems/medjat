<?php
/**
 * Standalone unit test for PayrollCalculator::matchLateTier (the tiered
 * late-deduction "ladder" matcher). No database required.
 *
 * Run:
 *   /Applications/MAMP/bin/php/php8.5.0/bin/php backend_medjet/tests/late_tier_test.php
 */

require __DIR__ . '/../core/PayrollCalculator.php';

$failures = 0;
$count = 0;

function check(string $name, $expected, $actual): void {
    global $failures, $count;
    $count++;
    if ($expected === $actual) {
        echo "  ✓ {$name}\n";
    } else {
        $failures++;
        echo "  ✗ {$name}\n";
        echo "      expected: " . var_export($expected, true) . "\n";
        echo "      actual:   " . var_export($actual, true) . "\n";
    }
}

// Ascending ladder: 15→0.25, 30→0.5, 60→1.0 (as getLateTiers returns it).
$tiers = [
    ['threshold_minutes' => 15, 'deduction_days' => 0.25],
    ['threshold_minutes' => 30, 'deduction_days' => 0.5],
    ['threshold_minutes' => 60, 'deduction_days' => 1.0],
];

$days = static fn(?array $t) => $t === null ? null : (float) $t['deduction_days'];

echo "matchLateTier:\n";
check('below lowest threshold → null', null, $days(PayrollCalculator::matchLateTier($tiers, 10)));
check('exactly on lowest (15) → 0.25', 0.25, $days(PayrollCalculator::matchLateTier($tiers, 15)));
check('between tiers (40) → 30 tier 0.5', 0.5, $days(PayrollCalculator::matchLateTier($tiers, 40)));
check('exactly on middle (30) → 0.5', 0.5, $days(PayrollCalculator::matchLateTier($tiers, 30)));
check('just below top (59) → 0.5', 0.5, $days(PayrollCalculator::matchLateTier($tiers, 59)));
check('exactly on top (60) → 1.0', 1.0, $days(PayrollCalculator::matchLateTier($tiers, 60)));
check('far above top (180) → 1.0', 1.0, $days(PayrollCalculator::matchLateTier($tiers, 180)));
check('empty ladder → null', null, $days(PayrollCalculator::matchLateTier([], 45)));

$single = [['threshold_minutes' => 20, 'deduction_days' => 0.5]];
check('single tier, below → null', null, $days(PayrollCalculator::matchLateTier($single, 19)));
check('single tier, at/above → 0.5', 0.5, $days(PayrollCalculator::matchLateTier($single, 25)));

echo "\n{$count} checks, {$failures} failure(s)\n";
exit($failures === 0 ? 0 : 1);
