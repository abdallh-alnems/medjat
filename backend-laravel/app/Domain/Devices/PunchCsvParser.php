<?php

declare(strict_types=1);

namespace App\Domain\Devices;

use DateTime;

/**
 * Reads a punch export from any fingerprint terminal.
 *
 * There is no standard for these files. Every vendor — and every firmware
 * revision — picks its own column names, its own date format and its own
 * delimiter, and the file usually arrives having been opened and re-saved in
 * Excel on an Arabic Windows. So nothing here assumes a layout: it reads the
 * header when there is one, and the *values* when there is not.
 *
 * Two rules. One bad row never costs the others — unparseable rows come back
 * with their line numbers and the rest still parse. And nothing is guessed
 * silently: where a file is genuinely ambiguous the verdict is reported back,
 * so a human can see what was assumed rather than discovering it in April's
 * payroll.
 */
final class PunchCsvParser
{
    /** Column-name aliases, in priority order, compared after normalising. */
    private const USER_ALIASES = [
        'userid', 'user', 'pin', 'employeeno', 'empno', 'employeeid',
        'enrollid', 'enrollno', 'badgenumber', 'badge', 'acno', 'personid',
        'employee', 'no', 'id',
    ];

    private const DATETIME_ALIASES = ['datetime', 'punchtime', 'checktime', 'attendancetime', 'timestamp', 'recordtime'];

    private const DATE_ALIASES = ['date', 'punchdate', 'checkdate', 'attendancedate'];

    private const TIME_ALIASES = ['time', 'punchtimeonly', 'clock'];

    private const VERIFY_ALIASES = ['verifymode', 'verifycode', 'verifytype', 'verify', 'mode', 'method', 'verifystate'];

    private const STATUS_ALIASES = ['status', 'state', 'inout', 'checktype', 'punchstate', 'attstate'];

    /** @var array<string, list<string>> */
    private const DATE_FORMATS = [
        'ymd' => ['Y-m-d', 'Y/m/d', 'Y.m.d'],
        'dmy' => ['d-m-Y', 'd/m/Y', 'd.m.Y'],
        'mdy' => ['m-d-Y', 'm/d/Y', 'm.d.Y'],
    ];

    /**
     * @return array{rows: list<array{line: int, user_id: string, punched_at: string, verify: int|null, status: int|null, raw: string}>, errors: list<array{line: int, reason: string, raw: string}>, delimiter: string, had_header: bool, date_order: string, date_order_ambiguous: bool}
     */
    public static function parse(string $raw): array
    {
        $raw = self::decode($raw);
        $lines = preg_split('/\r\n|\n|\r/', $raw) ?: [];

        // Blank lines are dropped but the numbering is kept, so an error report
        // points at the row the person sees in Excel.
        $numbered = [];
        foreach ($lines as $index => $line) {
            if (trim($line) !== '') {
                $numbered[] = ['line' => $index + 1, 'text' => $line];
            }
        }

        if ($numbered === []) {
            return self::emptyResult(',');
        }

        $delimiter = self::detectDelimiter($numbered[0]['text']);

        $records = [];
        foreach ($numbered as $entry) {
            $records[] = [
                'line' => $entry['line'],
                'cells' => str_getcsv($entry['text'], $delimiter, '"', '\\'),
                'raw' => $entry['text'],
            ];
        }

        $map = self::mapColumns($records);
        $dataRecords = $map['had_header'] ? array_slice($records, 1) : $records;

        // Day/month order is a property of the whole file, never of one row:
        // 03/04 is unknowable alone, but one 25/04 elsewhere settles every row.
        $order = self::resolveDateOrder($dataRecords, $map);

        $rows = [];
        $errors = [];

        foreach ($dataRecords as $record) {
            $parsed = self::parseRecord($record, $map, $order['order']);

            if (isset($parsed['reason'])) {
                $reason = $parsed['reason'];

                $errors[] = [
                    'line' => $record['line'],
                    'reason' => is_string($reason) ? $reason : 'unreadable_row',
                    'raw' => mb_substr($record['raw'], 0, 200),
                ];

                continue;
            }

            /** @var array{line: int, user_id: string, punched_at: string, verify: int|null, status: int|null, raw: string} $parsed */
            $rows[] = $parsed;
        }

        return [
            'rows' => $rows,
            'errors' => $errors,
            'delimiter' => $delimiter,
            'had_header' => $map['had_header'],
            'date_order' => $order['order'],
            'date_order_ambiguous' => $order['ambiguous'],
        ];
    }

    // ── Input normalisation ─────────────────────────────────────────────

    /**
     * Excel writes a byte-order mark and some terminal exports are UTF-16 —
     * either turns the first header cell into something no alias will match.
     */
    private static function decode(string $raw): string
    {
        if (str_starts_with($raw, "\xFF\xFE") || str_starts_with($raw, "\xFE\xFF")) {
            $converted = @mb_convert_encoding($raw, 'UTF-8', 'UTF-16');

            if (is_string($converted)) {
                $raw = $converted;
            }
        }

        $raw = preg_replace('/^\xEF\xBB\xBF/', '', $raw) ?? $raw;

        // Arabic-Indic digits arrive from Arabic Windows exports, and every
        // numeric check below expects ASCII.
        return str_replace(
            ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'],
            ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'],
            $raw,
        );
    }

    private static function detectDelimiter(string $headerLine): string
    {
        $best = ',';
        $bestCount = 0;

        foreach ([',', ';', "\t", '|'] as $candidate) {
            $count = substr_count($headerLine, $candidate);

            if ($count > $bestCount) {
                $bestCount = $count;
                $best = $candidate;
            }
        }

        return $best;
    }

    private static function normaliseHeader(string $value): string
    {
        return preg_replace('/[^a-z0-9]/', '', strtolower(trim($value))) ?? '';
    }

    // ── Which column holds what ─────────────────────────────────────────

    /**
     * Header names are tried first; when they are missing or unrecognised —
     * headerless exports are common — the columns are classified by what their
     * values look like instead.
     *
     * @param  list<array{line: int, cells: array<int, string|null>, raw: string}>  $records
     * @return array{user: int|null, datetime: int|null, date: int|null, time: int|null, verify: int|null, status: int|null, had_header: bool}
     */
    private static function mapColumns(array $records): array
    {
        $first = $records[0]['cells'];
        $headers = array_values(array_map(
            static fn (mixed $cell): string => self::normaliseHeader(is_scalar($cell) ? (string) $cell : ''),
            $first,
        ));

        // A header row is one whose cells are words rather than punch data. If
        // the first row already parses as a date it is data, and the file has
        // no header at all.
        $hadHeader = false;

        foreach ($headers as $header) {
            if ($header !== '' && ! ctype_digit($header)) {
                $hadHeader = true;

                break;
            }
        }

        if ($hadHeader && self::looksLikeDataRow($first)) {
            $hadHeader = false;
        }

        $map = ['user' => null, 'datetime' => null, 'date' => null, 'time' => null, 'verify' => null, 'status' => null];

        if ($hadHeader) {
            $map['user'] = self::matchAlias($headers, self::USER_ALIASES);
            $map['datetime'] = self::matchAlias($headers, self::DATETIME_ALIASES);
            $map['date'] = self::matchAlias($headers, self::DATE_ALIASES);
            $map['time'] = self::matchAlias($headers, self::TIME_ALIASES);
            $map['verify'] = self::matchAlias($headers, self::VERIFY_ALIASES);
            $map['status'] = self::matchAlias($headers, self::STATUS_ALIASES);

            // Some vendors label the full timestamp "Time" and others use it
            // for the clock alone. Believe the values, not the label.
            if ($map['datetime'] === null && $map['time'] !== null && $map['date'] === null) {
                $map['datetime'] = $map['time'];
                $map['time'] = null;
            }
        }

        self::sniffMissing($map, array_slice($records, $hadHeader ? 1 : 0, 25));

        $map['had_header'] = $hadHeader;

        /** @var array{user: int|null, datetime: int|null, date: int|null, time: int|null, verify: int|null, status: int|null, had_header: bool} $map */
        return $map;
    }

    /**
     * @param  list<string>  $headers
     * @param  list<string>  $aliases
     */
    private static function matchAlias(array $headers, array $aliases): ?int
    {
        foreach ($aliases as $alias) {
            $index = array_search($alias, $headers, true);

            if ($index !== false) {
                return (int) $index;
            }
        }

        return null;
    }

    /**
     * Fills whatever the header did not give us by looking at the values.
     *
     * @param  array<string, int|null|bool>  $map
     * @param  list<array{line: int, cells: array<int, string|null>, raw: string}>  $sample
     */
    private static function sniffMissing(array &$map, array $sample): void
    {
        if ($sample === []) {
            return;
        }

        $width = max(array_map(static fn (array $record): int => count($record['cells']), $sample));
        $kinds = [];

        for ($column = 0; $column < $width; $column++) {
            $values = [];

            foreach ($sample as $record) {
                $value = trim((string) ($record['cells'][$column] ?? ''));

                if ($value !== '') {
                    $values[] = $value;
                }
            }

            $kinds[$column] = $values === [] ? 'empty' : self::classify($values);
        }

        if ($map['datetime'] === null && $map['date'] === null) {
            $found = array_search('datetime', $kinds, true);
            $map['datetime'] = $found === false ? null : $found;

            if ($map['datetime'] === null) {
                $found = array_search('date', $kinds, true);
                $map['date'] = $found === false ? null : $found;
            }
        }

        if ($map['date'] !== null && $map['time'] === null) {
            $found = array_search('time', $kinds, true);
            $map['time'] = $found === false ? null : $found;
        }

        if ($map['user'] === null) {
            // The first purely numeric column that is not a date or a time.
            foreach ($kinds as $column => $kind) {
                if ($kind === 'int') {
                    $map['user'] = $column;

                    break;
                }
            }
        }
    }

    /**
     * @param  list<string>  $values
     */
    private static function classify(array $values): string
    {
        $counts = ['datetime' => 0, 'date' => 0, 'time' => 0, 'int' => 0];

        foreach ($values as $value) {
            $split = self::splitDateTime($value);

            if ($split['time'] !== null && self::looksLikeDate($split['date'])) {
                $counts['datetime']++;
            } elseif (self::looksLikeDate($value)) {
                $counts['date']++;
            } elseif (preg_match('/^\d{1,2}:\d{2}(:\d{2})?(\s*[APap][Mm])?$/', $value) === 1) {
                $counts['time']++;
            } elseif (ctype_digit($value)) {
                $counts['int']++;
            }
        }

        $total = count($values);

        // Four fifths, so a handful of blank or malformed cells does not stop a
        // column being recognised for what it plainly is.
        foreach ($counts as $kind => $hits) {
            if ($hits >= $total * 0.8) {
                return $kind;
            }
        }

        return 'text';
    }

    /**
     * @param  array<int, string|null>  $cells
     */
    private static function looksLikeDataRow(array $cells): bool
    {
        foreach ($cells as $cell) {
            $value = trim((string) $cell);

            if ($value !== '' && self::looksLikeDate(self::splitDateTime($value)['date'])) {
                return true;
            }
        }

        return false;
    }

    private static function looksLikeDate(string $value): bool
    {
        return preg_match('/^\d{1,4}[-\/.]\d{1,2}[-\/.]\d{1,4}$/', trim($value)) === 1;
    }

    /**
     * @return array{date: string, time: string|null}
     */
    private static function splitDateTime(string $value): array
    {
        $value = trim(str_replace('T', ' ', $value));
        $parts = preg_split('/\s+/', $value, 2);

        if ($parts === false || $parts === []) {
            return ['date' => $value, 'time' => null];
        }

        return ['date' => (string) $parts[0], 'time' => isset($parts[1]) ? (string) $parts[1] : null];
    }

    // ── Day or month first ──────────────────────────────────────────────

    /**
     * 03/04/2026 is either 3 April or 4 March and nothing in the row says
     * which. But a file is written by one device in one format, so a single
     * unambiguous row settles all of them: a first component above 12 proves
     * day-first, a second above 12 proves month-first.
     *
     * When the whole file is ambiguous, day-first is assumed — the format used
     * across Egypt and most of the world — and flagged, so the caller can say
     * so out loud rather than quietly filing April punches as March.
     *
     * @param  list<array{line: int, cells: array<int, string|null>, raw: string}>  $records
     * @param  array{datetime: int|null, date: int|null}  $map
     * @return array{order: string, ambiguous: bool}
     */
    private static function resolveDateOrder(array $records, array $map): array
    {
        $column = $map['datetime'] ?? $map['date'];

        if ($column === null) {
            return ['order' => 'dmy', 'ambiguous' => false];
        }

        $ambiguous = false;

        foreach ($records as $record) {
            $value = trim((string) ($record['cells'][$column] ?? ''));

            if ($value === '') {
                continue;
            }

            $date = self::splitDateTime($value)['date'];

            if (preg_match('/^(\d{1,4})[-\/.](\d{1,2})[-\/.](\d{1,4})$/', $date, $matches) !== 1) {
                continue;
            }

            // A four-digit leading component is a year: unambiguous.
            if (strlen($matches[1]) === 4) {
                return ['order' => 'ymd', 'ambiguous' => false];
            }

            if ((int) $matches[1] > 12) {
                return ['order' => 'dmy', 'ambiguous' => false];
            }

            if ((int) $matches[2] > 12) {
                return ['order' => 'mdy', 'ambiguous' => false];
            }

            $ambiguous = true;
        }

        return ['order' => 'dmy', 'ambiguous' => $ambiguous];
    }

    // ── One row ─────────────────────────────────────────────────────────

    /**
     * @param  array{line: int, cells: array<int, string|null>, raw: string}  $record
     * @param  array{user: int|null, datetime: int|null, date: int|null, time: int|null, verify: int|null, status: int|null}  $map
     * @return array<string, mixed>
     */
    private static function parseRecord(array $record, array $map, string $order): array
    {
        $cells = $record['cells'];
        $cell = static fn (?int $index): string => $index === null ? '' : trim((string) ($cells[$index] ?? ''));

        $userId = $cell($map['user']);

        if ($userId === '') {
            return ['reason' => 'no_user_id'];
        }

        // Exports pad the enrol id ("00012") while the terminal reports "12"
        // over the wire. Stripping it is what makes a file import and a live
        // device agree on who this is.
        $userId = ltrim($userId, '0');

        if ($userId === '') {
            $userId = '0';
        }

        if (mb_strlen($userId) > 32) {
            return ['reason' => 'user_id_too_long'];
        }

        if ($map['datetime'] !== null) {
            $rawWhen = $cell($map['datetime']);
        } elseif ($map['date'] !== null) {
            $rawWhen = trim($cell($map['date']).' '.$cell($map['time']));
        } else {
            return ['reason' => 'no_timestamp_column'];
        }

        if ($rawWhen === '') {
            return ['reason' => 'empty_timestamp'];
        }

        $punchedAt = self::toDateTime($rawWhen, $order);

        if ($punchedAt === null) {
            return ['reason' => 'unreadable_timestamp'];
        }

        $status = $cell($map['status']);

        return [
            'line' => $record['line'],
            'user_id' => $userId,
            'punched_at' => $punchedAt,
            'verify' => self::verifyMode($cell($map['verify'])),
            'status' => ctype_digit($status) ? (int) $status : null,
            'raw' => mb_substr($record['raw'], 0, 255),
        ];
    }

    private static function toDateTime(string $value, string $order): ?string
    {
        $split = self::splitDateTime($value);
        $date = $split['date'];
        $time = $split['time'] !== null ? trim($split['time']) : '';

        if (preg_match('/^(\d{1,4})[-\/.](\d{1,2})[-\/.](\d{1,4})$/', $date, $matches) !== 1) {
            return null;
        }

        // A four-digit leading component is always the year, whatever the
        // file's prevailing order says.
        $effective = strlen($matches[1]) === 4 ? 'ymd' : $order;

        foreach (self::DATE_FORMATS[$effective] ?? self::DATE_FORMATS['dmy'] as $format) {
            $candidate = $time === '' ? $date : $date.' '.$time;

            foreach (self::timeFormats($time) as $timeFormat) {
                // The leading "!" resets every field the format does not set.
                // Without it PHP fills the gaps from the current clock, so a
                // date-only row would be stamped with the time of the import.
                $full = '!'.($time === '' ? $format : $format.' '.$timeFormat);
                $parsed = DateTime::createFromFormat($full, $candidate);
                $errors = DateTime::getLastErrors();
                $failed = is_array($errors) && ($errors['error_count'] > 0 || $errors['warning_count'] > 0);

                if ($parsed !== false && ! $failed) {
                    // A date-only row is a punch with no clock, and midnight is
                    // the only honest reading; the sanity window downstream
                    // decides whether it is usable.
                    return $parsed->format('Y-m-d H:i:s');
                }
            }
        }

        return null;
    }

    /**
     * Either the numeric code the terminal uses or the word a human-readable
     * export prints.
     *
     * The codes match the protocol's, which is what turns this into the
     * recognition method on the attendance row — so a face punch imported from
     * a file is recorded as a face punch rather than falling back to
     * fingerprint.
     */
    private static function verifyMode(string $raw): ?int
    {
        $raw = trim($raw);

        if ($raw === '') {
            return null;
        }

        if (ctype_digit($raw)) {
            return (int) $raw;
        }

        $word = preg_replace('/[^a-z]/', '', strtolower($raw)) ?? '';

        return match (true) {
            str_contains($word, 'finger') || str_contains($word, 'fp') => 1,
            str_contains($word, 'face') => 15,
            str_contains($word, 'card') || str_contains($word, 'rfid') => 3,
            str_contains($word, 'password') || str_contains($word, 'pin') => 0,
            default => null,
        };
    }

    /**
     * @return list<string>
     */
    private static function timeFormats(string $time): array
    {
        if ($time === '') {
            return [''];
        }

        if (preg_match('/[APap][Mm]$/', $time) === 1) {
            return ['h:i:s A', 'h:i A', 'g:i:s A', 'g:i A'];
        }

        return ['H:i:s', 'H:i'];
    }

    /**
     * @return array{rows: list<array{line: int, user_id: string, punched_at: string, verify: int|null, status: int|null, raw: string}>, errors: list<array{line: int, reason: string, raw: string}>, delimiter: string, had_header: bool, date_order: string, date_order_ambiguous: bool}
     */
    private static function emptyResult(string $delimiter): array
    {
        return [
            'rows' => [],
            'errors' => [],
            'delimiter' => $delimiter,
            'had_header' => false,
            'date_order' => 'dmy',
            'date_order_ambiguous' => false,
        ];
    }
}
