<?php

declare(strict_types=1);

namespace App\Modules\Devices\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Http\ApiResponse;
use App\Modules\Audit\Domain\AuditLog;
use App\Modules\Devices\Domain\AttendanceDevice;
use App\Modules\Devices\Domain\DevicePunches;
use App\Modules\Devices\Domain\DeviceUsers;
use App\Modules\Devices\Domain\PunchCsvParser;
use App\Modules\Devices\Domain\PunchIngestor;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Port of api/app/devices/import_punches.php.
 *
 * The vendor-neutral way in. The push endpoint speaks one manufacturer's
 * dialect and only devices that talk it can use it; every terminal ever made,
 * of any brand, can write a file to a USB stick. That covers the two customers
 * the push endpoint cannot reach at all: the one whose device is a brand we
 * have no adapter for, and the one whose device is not on a network.
 *
 * Both routes converge immediately — parsed rows are stored and handed to the
 * same ingestor that judges a live punch — so linking, direction, clock sanity
 * and repeat-tap suppression are identical whether a punch arrived over the
 * wire or on a stick.
 */
final class ImportPunchesController
{
    /** Well below a realistic export: a year of punches for 500 staff is ~5 MB. */
    private const MAX_BYTES = 8388608;

    private const MAX_ROWS = 20000;

    public function __construct(private readonly PunchIngestor $ingestor) {}

    public function __invoke(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = DeviceFleetController::admin($request)->id;

        $raw = $this->contents($request);
        $device = $this->destination($request, $tenantId, $adminId);
        $deviceId = Value::int($device['id'] ?? null);
        $branchId = Value::int($device['branch_id'] ?? null);

        $parsed = PunchCsvParser::parse($raw);

        if ($parsed['rows'] === [] && $parsed['errors'] === []) {
            throw new ApiFailure('The file has no rows', 422, 'FILE_EMPTY');
        }

        if (count($parsed['rows']) > self::MAX_ROWS) {
            throw new ApiFailure('The file has too many rows; split it into smaller files', 413, 'TOO_MANY_ROWS');
        }

        // Nothing readable at all almost always means the wrong column was
        // taken for the user id or the timestamp — say so, rather than
        // reporting "0 imported" and leaving somebody to guess.
        if ($parsed['rows'] === []) {
            throw new ApiFailure(
                'No row in this file could be read. Check that it has an employee/user id column and a date column.',
                422,
                'NO_READABLE_ROWS',
                ['errors' => array_slice($parsed['errors'], 0, 20), 'error_count' => count($parsed['errors'])],
            );
        }

        if ($request->boolean('preview')) {
            return $this->preview($parsed, $deviceId, $branchId);
        }

        return $this->import($parsed, $device, $deviceId, $branchId, $tenantId, $adminId);
    }

    /**
     * A preview commits nothing.
     *
     * Bulk imports are the one place a mistake is expensive and invisible, so
     * the admin sees what was understood — especially the day/month reading —
     * before any of it is written.
     *
     * @param  array{rows: list<array{line: int, user_id: string, punched_at: string, verify: int|null, status: int|null, raw: string}>, errors: list<array{line: int, reason: string, raw: string}>, delimiter: string, had_header: bool, date_order: string, date_order_ambiguous: bool}  $parsed
     */
    private function preview(array $parsed, int $deviceId, int $branchId): JsonResponse
    {
        $rows = $parsed['rows'];

        return ApiResponse::success([
            'preview' => true,
            'device_id' => $deviceId,
            'branch_id' => $branchId,
            'readable_rows' => count($rows),
            'unreadable_rows' => count($parsed['errors']),
            'first_punch' => $rows[0]['punched_at'],
            'last_punch' => $rows[count($rows) - 1]['punched_at'],
            'distinct_users' => count(array_unique(array_column($rows, 'user_id'))),
            'date_order' => $parsed['date_order'],
            'date_order_ambiguous' => $parsed['date_order_ambiguous'],
            'had_header' => $parsed['had_header'],
            'sample' => array_map(static fn (array $row): array => [
                'line' => $row['line'],
                'device_user_id' => $row['user_id'],
                'punched_at' => $row['punched_at'],
            ], array_slice($rows, 0, 10)),
            'errors' => array_slice($parsed['errors'], 0, 20),
        ]);
    }

    /**
     * @param  array{rows: list<array{line: int, user_id: string, punched_at: string, verify: int|null, status: int|null, raw: string}>, errors: list<array{line: int, reason: string, raw: string}>, delimiter: string, had_header: bool, date_order: string, date_order_ambiguous: bool}  $parsed
     * @param  array<string, mixed>  $device
     */
    private function import(array $parsed, array $device, int $deviceId, int $branchId, int $tenantId, int $adminId): JsonResponse
    {
        $rows = $parsed['rows'];

        $now = PunchIngestor::now($device);
        $results = array_fill_keys(DevicePunches::STATES, 0);
        $alreadyImported = 0;
        $seenUsers = [];

        foreach ($rows as $row) {
            $stored = DevicePunches::record(
                $deviceId, $tenantId, $row['user_id'], $row['punched_at'],
                $row['status'], $row['verify'], null, $row['raw'],
            );

            // Re-importing the same export happens constantly — the obvious way
            // to catch up is to export everything again — and must not create a
            // second attendance row for the same tap.
            if ($stored['duplicate']) {
                $alreadyImported++;

                continue;
            }

            if (! isset($seenUsers[$row['user_id']])) {
                DeviceUsers::ensure($deviceId, $tenantId, $row['user_id']);
                $seenUsers[$row['user_id']] = true;
            }

            DeviceUsers::touchPunch($deviceId, $row['user_id'], $row['punched_at']);

            $state = $this->ingestor->apply($device, [
                'id' => $stored['id'],
                'device_user_id' => $row['user_id'],
                'punched_at' => $row['punched_at'],
                'status_code' => $row['status'],
                'verify_mode' => $row['verify'],
            ], $now);

            if (array_key_exists($state, $results)) {
                $results[$state]++;
            }
        }

        AttendanceDevice::touchPunch($deviceId, $rows[count($rows) - 1]['punched_at']);

        AuditLog::record($tenantId, $adminId, 'device.import_punches', 'device', $deviceId, [
            'rows' => count($rows),
            'applied' => $results['applied'],
            'unmatched' => $results['unmatched'],
            'already_imported' => $alreadyImported,
        ]);

        return ApiResponse::success([
            'preview' => false,
            'device_id' => $deviceId,
            'branch_id' => $branchId,
            'read_rows' => count($rows),
            'unreadable_rows' => count($parsed['errors']),
            'already_imported' => $alreadyImported,
            'results' => $results,
            'date_order' => $parsed['date_order'],
            'date_order_ambiguous' => $parsed['date_order_ambiguous'],
            // Unmatched is the expected outcome of a first import, not a
            // failure: those User IDs have never been linked. Reported apart
            // from the rest so the screen sends the admin to the linking page
            // instead of showing a count of things that "went wrong".
            'unlinked_users' => count(DeviceUsers::listForDevice($deviceId, $tenantId, 'unlinked')),
            'errors' => array_slice($parsed['errors'], 0, 20),
        ]);
    }

    /**
     * The file may arrive as an upload or as pasted text, because the same
     * endpoint serves the web page and the mobile app.
     */
    private function contents(Request $request): string
    {
        $file = $request->file('file');

        if ($file !== null) {
            if (is_array($file)) {
                throw new ApiFailure('Upload one file at a time', 422, 'UPLOAD_FAILED');
            }

            if (! $file->isValid()) {
                throw new ApiFailure('File upload failed', 400, 'UPLOAD_FAILED');
            }

            if ($file->getSize() > self::MAX_BYTES) {
                throw new ApiFailure('File is too large', 413, 'FILE_TOO_LARGE');
            }

            $raw = file_get_contents($file->getRealPath());

            if ($raw === false) {
                throw new ApiFailure('File upload failed', 400, 'UPLOAD_FAILED');
            }

            return $raw;
        }

        $pasted = Value::string($request->input('csv_text'));

        if (strlen($pasted) > self::MAX_BYTES) {
            throw new ApiFailure('File is too large', 413, 'FILE_TOO_LARGE');
        }

        if (trim($pasted) === '') {
            throw new ApiFailure('A CSV file is required', 422, 'FILE_REQUIRED');
        }

        return $pasted;
    }

    /**
     * Either an already-registered terminal — the customer has one, it is just
     * offline — or a branch, in which case a stand-in device is created so that
     * every punch still has a device row to hang off.
     *
     * @return array<string, mixed>
     */
    private function destination(Request $request, int $tenantId, int $adminId): array
    {
        $deviceId = Value::int($request->input('device_id'));

        if ($deviceId > 0) {
            $device = AttendanceDevice::find($deviceId, $tenantId);

            if ($device === null) {
                throw new ApiFailure('Device not found', 404, 'not_found');
            }

            if (Value::nullableInt($device['branch_id'] ?? null) === null) {
                throw new ApiFailure('This device is not assigned to a branch', 422, 'DEVICE_WITHOUT_BRANCH');
            }

            return $device;
        }

        $branchId = Value::int($request->input('branch_id'));

        if ($branchId <= 0) {
            throw new ApiFailure('Choose a branch or a device for the import', 422, 'BRANCH_REQUIRED');
        }

        DeviceFleetController::assertBranchExists($branchId, $tenantId);

        return AttendanceDevice::ensureFileImportDevice($tenantId, $branchId, $adminId);
    }
}
