<?php

/**
 * Reads a punch export from any fingerprint terminal.
 *
 * There is no standard for these files. Every vendor — and every firmware
 * revision — picks its own column names, its own date format, and its own
 * delimiter, and the file usually arrives having been opened and re-saved in
 * Excel on an Arabic Windows. So this parser does not assume a layout: it looks
 * at the header when there is one, and at the *values* when there is not.
 *
 * Rules:
 *   1. One bad row never costs the others. Unparseable rows come back in
 *      `errors` with their line number; the rest still parse.
 *   2. Nothing is guessed silently. Where the file is genuinely ambiguous
 *      (see the day/month note below) the verdict is reported back to the
 *      caller so a human can see what was assumed.
 */
final class PunchCsvParser {
    /** Column-name aliases, in priority order. Compared after lower-casing and stripping non-alphanumerics. */
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

    /** Date orders we can read. Time part is optional and appended separately. */
    private const DATE_FORMATS = [
        'ymd' => ['Y-m-d', 'Y/m/d', 'Y.m.d'],
        'dmy' => ['d-m-Y', 'd/m/Y', 'd.m.Y'],
        'mdy' => ['m-d-Y', 'm/d/Y', 'm.d.Y'],
    ];

    /**
     * @return array{
     *   rows: list<array{line:int,user_id:string,punched_at:string,verify:?int,status:?int,raw:string}>,
     *   errors: list<array{line:int,reason:string,raw:string}>,
     *   delimiter: string,
     *   had_header: bool,
     *   date_order: string,
     *   date_order_ambiguous: bool
     * }
     */
    public static function parse(string $raw): array {
        $raw = self::decode($raw);
        $lines = preg_split('/\r\n|\n|\r/', $raw) ?: [];

        // Blank lines are dropped here but line numbers are kept, so an error
        // report points at the row the admin sees in Excel.
        $numbered = [];
        foreach ($lines as $i => $line) {
            if (trim($line) !== '') {
                $numbered[] = ['line' => $i + 1, 'text' => $line];
            }
        }
        if ($numbered === []) {
            return self::emptyResult(',');
        }

        $delimiter = self::detectDelimiter($numbered[0]['text']);
        $records = [];
        foreach ($numbered as $entry) {
            $records[] = ['line' => $entry['line'], 'cells' => str_getcsv($entry['text'], $delimiter, '"', '\\'), 'raw' => $entry['text']];
        }

        $map = self::mapColumns($records, $delimiter);
        $dataRecords = $map['had_header'] ? array_slice($records, 1) : $records;

        // Day/month order is a property of the whole file, never of one row:
        // 03/04 is unknowable alone, but one 25/04 elsewhere settles every row.
        $order = self::resolveDateOrder($dataRecords, $map);

        $rows = [];
        $errors = [];
        foreach ($dataRecords as $rec) {
            $parsed = self::parseRecord($rec, $map, $order['order']);
            if (isset($parsed['reason'])) {
                $errors[] = ['line' => $rec['line'], 'reason' => $parsed['reason'], 'raw' => mb_substr($rec['raw'], 0, 200)];
            } else {
                $rows[] = $parsed;
            }
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

    // ── input normalisation ─────────────────────────────────────────────

    /**
     * Excel writes a UTF-8 BOM, and some terminal exports are UTF-16 — both
     * turn the first header cell into something no alias will ever match.
     */
    private static function decode(string $raw): string {
        if (str_starts_with($raw, "\xFF\xFE") || str_starts_with($raw, "\xFE\xFF")) {
            $converted = @mb_convert_encoding($raw, 'UTF-8', 'UTF-16');
            if ($converted !== false) {
                $raw = $converted;
            }
        }
        $raw = preg_replace('/^\xEF\xBB\xBF/', '', $raw) ?? $raw;

        // Arabic-Indic digits reach us from Arabic Windows exports; every
        // numeric check below expects ASCII.
        return str_replace(
            ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'],
            ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'],
            $raw
        );
    }

    private static function detectDelimiter(string $headerLine): string {
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

    private static function normaliseHeader(string $value): string {
        return preg_replace('/[^a-z0-9]/', '', strtolower(trim($value))) ?? '';
    }

    // ── column mapping ──────────────────────────────────────────────────

    /**
     * Works out which column holds what. Header names are tried first; when
     * they are missing or unrecognised (headerless exports are common) the
     * columns are classified by what their values look like instead.
     */
    private static function mapColumns(array $records, string $delimiter): array {
        $first = $records[0]['cells'];
        $headers = array_map([self::class, 'normaliseHeader'], $first);

        // A header row is one whose cells are words, not punch data. If the
        // first row already parses as a date it is data, and the file has none.
        $hadHeader = false;
        foreach ($headers as $h) {
            if ($h !== '' && !ctype_digit($h)) {
                $hadHeader = true;
                break;
            }
        }
        if ($hadHeader && self::looksLikeDataRow($first)) {
            $hadHeader = false;
        }

        $map = ['user' => null, 'datetime' => null, 'date' => null, 'time' => null, 'verify' => null, 'status' => null];

        if ($hadHeader) {
            $map['user']     = self::matchAlias($headers, self::USER_ALIASES);
            $map['datetime'] = self::matchAlias($headers, self::DATETIME_ALIASES);
            $map['date']     = self::matchAlias($headers, self::DATE_ALIASES);
            $map['time']     = self::matchAlias($headers, self::TIME_ALIASES);
            $map['verify']   = self::matchAlias($headers, self::VERIFY_ALIASES);
            $map['status']   = self::matchAlias($headers, self::STATUS_ALIASES);

            // "Time" is used by some vendors for the full timestamp and by
            // others for the clock alone. Believe the values, not the label.
            if ($map['datetime'] === null && $map['time'] !== null && $map['date'] === null) {
                $map['datetime'] = $map['time'];
                $map['time'] = null;
            }
        }

        $sample = array_slice($records, $hadHeader ? 1 : 0, 25);
        self::sniffMissing($map, $sample);

        $map['had_header'] = $hadHeader;
        return $map;
    }

    private static function matchAlias(array $headers, array $aliases): ?int {
        foreach ($aliases as $alias) {
            $index = array_search($alias, $headers, true);
            if ($index !== false) {
                return (int) $index;
            }
        }
        return null;
    }

    /** Fills whatever the header did not give us by looking at the values. */
    private static function sniffMissing(array &$map, array $sample): void {
        if ($sample === []) {
            return;
        }
        $width = max(array_map(static fn($r) => count($r['cells']), $sample));

        $kinds = [];
        for ($col = 0; $col < $width; $col++) {
            $values = [];
            foreach ($sample as $rec) {
                $v = trim((string) ($rec['cells'][$col] ?? ''));
                if ($v !== '') {
                    $values[] = $v;
                }
            }
            $kinds[$col] = $values === [] ? 'empty' : self::classify($values);
        }

        if ($map['datetime'] === null && $map['date'] === null) {
            $map['datetime'] = array_search('datetime', $kinds, true) ?: null;
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
            foreach ($kinds as $col => $kind) {
                if ($kind === 'int') {
                    $map['user'] = $col;
                    break;
                }
            }
        }
    }

    private static function classify(array $values): string {
        $datetime = 0; $date = 0; $time = 0; $int = 0;
        foreach ($values as $v) {
            if (self::splitDateTime($v)['time'] !== null && self::looksLikeDate(self::splitDateTime($v)['date'])) {
                $datetime++;
            } elseif (self::looksLikeDate($v)) {
                $date++;
            } elseif (preg_match('/^\d{1,2}:\d{2}(:\d{2})?(\s*[APap][Mm])?$/', $v)) {
                $time++;
            } elseif (ctype_digit($v)) {
                $int++;
            }
        }
        $total = count($values);
        foreach (['datetime' => $datetime, 'date' => $date, 'time' => $time, 'int' => $int] as $kind => $hits) {
            if ($hits >= $total * 0.8) {
                return $kind;
            }
        }
        return 'text';
    }

    private static function looksLikeDataRow(array $cells): bool {
        foreach ($cells as $cell) {
            $cell = trim((string) $cell);
            if ($cell !== '' && self::looksLikeDate(self::splitDateTime($cell)['date'])) {
                return true;
            }
        }
        return false;
    }

    private static function looksLikeDate(string $value): bool {
        return (bool) preg_match('/^\d{1,4}[-\/.]\d{1,2}[-\/.]\d{1,4}$/', trim($value));
    }

    /** Splits "2026-07-31 08:03:00" into its date and time halves. */
    private static function splitDateTime(string $value): array {
        $value = trim(str_replace('T', ' ', $value));
        $parts = preg_split('/\s+/', $value, 2) ?: [$value];
        return ['date' => $parts[0] ?? '', 'time' => $parts[1] ?? null];
    }

    // ── date order ──────────────────────────────────────────────────────

    /**
     * 03/04/2026 is either 3 April or 4 March and nothing in the row says
     * which. But a file is written by one device in one format, so a single
     * unambiguous row settles all of them: any first component above 12 proves
     * day-first, any second component above 12 proves month-first.
     *
     * When the whole file is ambiguous we assume day-first — the format used
     * across Egypt and most of the world — and flag it so the caller can say so
     * out loud rather than quietly filing April punches as March.
     */
    private static function resolveDateOrder(array $records, array $map): array {
        $col = $map['datetime'] ?? $map['date'];
        if ($col === null) {
            return ['order' => 'dmy', 'ambiguous' => false];
        }

        $ambiguous = false;
        foreach ($records as $rec) {
            $value = trim((string) ($rec['cells'][$col] ?? ''));
            if ($value === '') {
                continue;
            }
            $date = self::splitDateTime($value)['date'];
            if (!preg_match('/^(\d{1,4})[-\/.](\d{1,2})[-\/.](\d{1,4})$/', $date, $m)) {
                continue;
            }
            // A 4-digit leading component is a year: the order is unambiguous.
            if (strlen($m[1]) === 4) {
                return ['order' => 'ymd', 'ambiguous' => false];
            }
            if ((int) $m[1] > 12) {
                return ['order' => 'dmy', 'ambiguous' => false];
            }
            if ((int) $m[2] > 12) {
                return ['order' => 'mdy', 'ambiguous' => false];
            }
            $ambiguous = true;
        }

        return ['order' => 'dmy', 'ambiguous' => $ambiguous];
    }

    // ── row parsing ─────────────────────────────────────────────────────

    private static function parseRecord(array $rec, array $map, string $order): array {
        $cells = $rec['cells'];
        $cell = static fn(?int $i): string => $i === null ? '' : trim((string) ($cells[$i] ?? ''));

        $userId = $cell($map['user']);
        if ($userId === '') {
            return ['reason' => 'no_user_id'];
        }
        // ZK exports pad the enrol id ("00012"); the terminal itself reports
        // "12" over ADMS. Strip the padding so a file import and a live device
        // agree on who this is.
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
            $rawWhen = trim($cell($map['date']) . ' ' . $cell($map['time']));
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

        $statusRaw = $cell($map['status']);

        return [
            'line' => $rec['line'],
            'user_id' => $userId,
            'punched_at' => $punchedAt,
            'verify' => self::verifyMode($cell($map['verify'])),
            'status' => ctype_digit($statusRaw) ? (int) $statusRaw : null,
            'raw' => mb_substr($rec['raw'], 0, 255),
        ];
    }

    private static function toDateTime(string $value, string $order): ?string {
        $split = self::splitDateTime($value);
        $date = $split['date'];
        $time = $split['time'] !== null ? trim($split['time']) : '';

        if (!preg_match('/^(\d{1,4})[-\/.](\d{1,2})[-\/.](\d{1,4})$/', $date, $m)) {
            return null;
        }

        // A 4-digit leading component is always the year, whatever the file's
        // prevailing order says.
        $effective = strlen($m[1]) === 4 ? 'ymd' : $order;

        foreach (self::DATE_FORMATS[$effective] as $format) {
            $candidate = $time === '' ? $date : $date . ' ' . $time;
            foreach (self::timeFormats($time) as $timeFormat) {
                // The leading "!" resets every field the format does not set.
                // Without it PHP fills the gaps from the current clock, so a
                // date-only row would be stamped with the time of the import
                // and an "H:i" row would carry today's seconds.
                $full = '!' . ($time === '' ? $format : $format . ' ' . $timeFormat);
                $dt = DateTime::createFromFormat($full, $candidate);
                $errors = DateTime::getLastErrors();
                $failed = is_array($errors) && ($errors['error_count'] > 0 || $errors['warning_count'] > 0);
                if ($dt !== false && !$failed) {
                    // A date-only row is a punch with no clock; midnight is the
                    // only honest reading, and the sanity window downstream
                    // decides whether it is usable.
                    return $dt->format('Y-m-d H:i:s');
                }
            }
        }
        return null;
    }

    /**
     * Verify mode, as either the numeric code the terminal uses or the word a
     * human-readable export prints. Codes match ZktecoAdms::VERIFY_MODES, which
     * is what turns this into the recognition method on the attendance row —
     * so a face punch imported from a file is recorded as a face punch rather
     * than falling back to fingerprint.
     */
    private static function verifyMode(string $raw): ?int {
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

    private static function timeFormats(string $time): array {
        if ($time === '') {
            return [''];
        }
        if (preg_match('/[APap][Mm]$/', $time)) {
            return ['h:i:s A', 'h:i A', 'g:i:s A', 'g:i A'];
        }
        return ['H:i:s', 'H:i'];
    }

    private static function emptyResult(string $delimiter): array {
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
