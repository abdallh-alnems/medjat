<?php

declare(strict_types=1);

namespace App\Modules\Payroll\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Support\Value;
use Illuminate\Http\Request;

/**
 * The optional "this was actually paid on" date.
 *
 * Kept as a plain calendar date rather than a timestamp: a company recording a
 * transfer that cleared last Thursday is stating a date, and turning that into
 * an instant would invent a time nobody supplied.
 */
final class PaidAt
{
    public static function fromRequest(Request $request): ?string
    {
        $raw = $request->input('paid_at');

        if ($raw === null || $raw === '') {
            return null;
        }

        $paidAt = Value::string($raw);

        if (preg_match('/^\d{4}-\d{2}-\d{2}$/', $paidAt) !== 1) {
            throw new ApiFailure('paid_at must be YYYY-MM-DD', 422, 'paid_at_yyyy_mm_dd');
        }

        return $paidAt;
    }
}
