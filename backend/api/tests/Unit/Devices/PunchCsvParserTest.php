<?php

declare(strict_types=1);

namespace Tests\Unit\Devices;

use App\Modules\Devices\Domain\PunchCsvParser;
use PHPUnit\Framework\TestCase;

/**
 * Reading a punch export from a terminal nobody told us about.
 *
 * There is no standard for these files, so the cases here are shapes that
 * actually turn up: no header, a semicolon delimiter, an Excel byte-order mark,
 * Arabic-Indic digits, a padded enrol id, and a day/month order that only one
 * row in the file settles.
 */
final class PunchCsvParserTest extends TestCase
{
    public function test_a_plain_export_with_a_header_is_read(): void
    {
        $parsed = PunchCsvParser::parse(
            "UserID,DateTime,Verify,Status\n12,2026-08-30 08:03:00,1,0\n13,2026-08-30 17:10:00,1,1\n"
        );

        $this->assertTrue($parsed['had_header']);
        $this->assertCount(2, $parsed['rows']);
        $this->assertSame('12', $parsed['rows'][0]['user_id']);
        $this->assertSame('2026-08-30 08:03:00', $parsed['rows'][0]['punched_at']);
        $this->assertSame(1, $parsed['rows'][0]['verify']);
        $this->assertSame(0, $parsed['rows'][0]['status']);
    }

    public function test_a_headerless_export_is_read_from_its_values(): void
    {
        // Common enough that assuming a header would lose the first punch.
        $parsed = PunchCsvParser::parse("12,2026-08-30 08:03:00,1,0\n13,2026-08-30 17:10:00,1,1\n");

        $this->assertFalse($parsed['had_header']);
        $this->assertCount(2, $parsed['rows']);
        $this->assertSame('12', $parsed['rows'][0]['user_id']);
    }

    public function test_a_semicolon_delimiter_is_detected(): void
    {
        $parsed = PunchCsvParser::parse("UserID;DateTime\n12;2026-08-30 08:03:00\n");

        $this->assertSame(';', $parsed['delimiter']);
        $this->assertCount(1, $parsed['rows']);
    }

    public function test_a_tab_delimiter_is_detected(): void
    {
        $parsed = PunchCsvParser::parse("UserID\tDateTime\n12\t2026-08-30 08:03:00\n");

        $this->assertSame("\t", $parsed['delimiter']);
        $this->assertCount(1, $parsed['rows']);
    }

    public function test_excels_byte_order_mark_does_not_break_the_first_column(): void
    {
        // Without stripping it the first header cell matches no alias, and the
        // user id column is never found.
        $parsed = PunchCsvParser::parse("\xEF\xBB\xBFUserID,DateTime\n12,2026-08-30 08:03:00\n");

        $this->assertCount(1, $parsed['rows']);
        $this->assertSame('12', $parsed['rows'][0]['user_id']);
    }

    public function test_arabic_indic_digits_are_read_as_numbers(): void
    {
        // Arabic Windows exports write them, and every numeric check expects
        // ASCII.
        $parsed = PunchCsvParser::parse("UserID,DateTime\n١٢,٢٠٢٦-٠٨-٣٠ ٠٨:٠٣:٠٠\n");

        $this->assertCount(1, $parsed['rows']);
        $this->assertSame('12', $parsed['rows'][0]['user_id']);
        $this->assertSame('2026-08-30 08:03:00', $parsed['rows'][0]['punched_at']);
    }

    public function test_a_padded_enrol_id_matches_what_the_terminal_reports(): void
    {
        // Exports pad it ("00012") while the device reports "12" over the wire;
        // without stripping, a file import and a live device would disagree
        // about who this is.
        $parsed = PunchCsvParser::parse("UserID,DateTime\n00012,2026-08-30 08:03:00\n");

        $this->assertSame('12', $parsed['rows'][0]['user_id']);
    }

    public function test_a_separate_date_and_time_column_are_joined(): void
    {
        $parsed = PunchCsvParser::parse("UserID,Date,Time\n12,2026-08-30,08:03:00\n");

        $this->assertSame('2026-08-30 08:03:00', $parsed['rows'][0]['punched_at']);
    }

    public function test_a_date_with_no_time_is_read_as_midnight(): void
    {
        // The only honest reading; whether it is usable is decided downstream.
        $parsed = PunchCsvParser::parse("UserID,Date\n12,2026-08-30\n");

        $this->assertSame('2026-08-30 00:00:00', $parsed['rows'][0]['punched_at']);
    }

    public function test_a_twelve_hour_clock_is_read(): void
    {
        $parsed = PunchCsvParser::parse("UserID,DateTime\n12,2026-08-30 05:03:00 PM\n");

        $this->assertSame('2026-08-30 17:03:00', $parsed['rows'][0]['punched_at']);
    }

    // ── Day or month first ──────────────────────────────────────────────

    public function test_one_unambiguous_row_settles_the_whole_file(): void
    {
        // 03/04 is unknowable alone, but 25/04 elsewhere proves day-first.
        $parsed = PunchCsvParser::parse("UserID,Date\n12,03/04/2026\n13,25/04/2026\n");

        $this->assertSame('dmy', $parsed['date_order']);
        $this->assertFalse($parsed['date_order_ambiguous']);
        $this->assertSame('2026-04-03 00:00:00', $parsed['rows'][0]['punched_at']);
    }

    public function test_a_month_first_file_is_recognised(): void
    {
        $parsed = PunchCsvParser::parse("UserID,Date\n12,03/04/2026\n13,04/25/2026\n");

        $this->assertSame('mdy', $parsed['date_order']);
        $this->assertSame('2026-03-04 00:00:00', $parsed['rows'][0]['punched_at']);
    }

    public function test_an_entirely_ambiguous_file_says_so_out_loud(): void
    {
        // Day-first is assumed — the format used across Egypt and most of the
        // world — but the caller is told, rather than quietly filing April
        // punches as March.
        $parsed = PunchCsvParser::parse("UserID,Date\n12,03/04/2026\n13,05/06/2026\n");

        $this->assertSame('dmy', $parsed['date_order']);
        $this->assertTrue($parsed['date_order_ambiguous']);
    }

    public function test_a_four_digit_year_needs_no_guessing(): void
    {
        $parsed = PunchCsvParser::parse("UserID,Date\n12,2026-03-04\n");

        $this->assertSame('ymd', $parsed['date_order']);
        $this->assertFalse($parsed['date_order_ambiguous']);
    }

    // ── Bad rows ────────────────────────────────────────────────────────

    public function test_one_bad_row_never_costs_the_others(): void
    {
        $parsed = PunchCsvParser::parse(
            "UserID,DateTime\n12,2026-08-30 08:03:00\n13,not-a-date\n14,2026-08-30 09:00:00\n"
        );

        $this->assertCount(2, $parsed['rows']);
        $this->assertCount(1, $parsed['errors']);
        // The line number is the one the person sees in Excel.
        $this->assertSame(3, $parsed['errors'][0]['line']);
    }

    public function test_a_row_with_no_user_id_is_reported_not_guessed(): void
    {
        $parsed = PunchCsvParser::parse("UserID,DateTime\n,2026-08-30 08:03:00\n");

        $this->assertSame([], $parsed['rows']);
        $this->assertSame('no_user_id', $parsed['errors'][0]['reason']);
    }

    public function test_an_empty_file_produces_nothing_rather_than_an_error(): void
    {
        $parsed = PunchCsvParser::parse("\n\n  \n");

        $this->assertSame([], $parsed['rows']);
        $this->assertSame([], $parsed['errors']);
    }

    public function test_blank_lines_do_not_shift_the_reported_line_numbers(): void
    {
        $parsed = PunchCsvParser::parse("UserID,DateTime\n\n12,nonsense\n");

        $this->assertSame(3, $parsed['errors'][0]['line']);
    }

    // ── How the punch was made ──────────────────────────────────────────

    public function test_a_written_verify_mode_maps_to_its_code(): void
    {
        // So a face punch imported from a file is recorded as a face punch
        // rather than falling back to fingerprint.
        $parsed = PunchCsvParser::parse("UserID,DateTime,VerifyMode\n12,2026-08-30 08:03:00,Face\n");

        $this->assertSame(15, $parsed['rows'][0]['verify']);
    }

    public function test_a_numeric_verify_mode_is_taken_as_written(): void
    {
        $parsed = PunchCsvParser::parse("UserID,DateTime,VerifyMode\n12,2026-08-30 08:03:00,3\n");

        $this->assertSame(3, $parsed['rows'][0]['verify']);
    }

    public function test_an_unrecognised_verify_word_is_left_unknown(): void
    {
        $parsed = PunchCsvParser::parse("UserID,DateTime,VerifyMode\n12,2026-08-30 08:03:00,telepathy\n");

        $this->assertNull($parsed['rows'][0]['verify']);
    }
}
