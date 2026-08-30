<?php

declare(strict_types=1);

namespace App\Modules\Payroll\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Modules\Payroll\Domain\Payslip\PayslipPdf;
use Illuminate\Support\Facades\Log;
use Symfony\Component\HttpFoundation\BinaryFileResponse;
use Throwable;

/**
 * Rendering a payslip and handing it back as a file.
 *
 * A failed render must never reach the client as a partial download: a file
 * that does not begin with "%PDF-" is rejected by every reader with an
 * unhelpful message, and the employee is left believing their payslip is
 * corrupt rather than that generation failed. So the file is verified to exist
 * and be non-empty before a single byte is promised.
 */
final class PayslipDownload
{
    /**
     * @param  array<string, mixed>  $tenant
     * @param  array<string, mixed>  $employee
     * @param  array<string, mixed>  $breakdown
     */
    public static function stream(
        array $tenant,
        array $employee,
        array $breakdown,
        string $month,
        int $employeeId,
    ): BinaryFileResponse {
        if ($breakdown === []) {
            throw new ApiFailure('Payroll slip not found', 404, 'not_found');
        }

        try {
            $path = PayslipPdf::generate($tenant, $employee, $breakdown, $month);
        } catch (Throwable $e) {
            Log::error('Payslip PDF generation failed', ['employee_id' => $employeeId, 'exception' => $e]);

            throw new ApiFailure('Failed to generate payslip', 500, 'failed_generate_payslip');
        }

        if (! is_file($path) || filesize($path) === 0) {
            Log::error('Payslip PDF missing after generation', ['employee_id' => $employeeId, 'path' => $path]);

            throw new ApiFailure('Failed to generate payslip', 500, 'failed_generate_payslip');
        }

        return (new BinaryFileResponse($path))
            ->setContentDisposition('attachment', "payslip_{$employeeId}_{$month}.pdf")
            ->deleteFileAfterSend(false)
            ->setPrivate();
    }
}
