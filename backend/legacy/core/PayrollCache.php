<?php

/// Tiny file-cache helper for the payroll live overview. Backs the X-Cache
/// header in `live.php` and lets mutating endpoints invalidate immediately
/// so users don't see a stale draft/paid state after acting.
final class PayrollCache {
    public static function invalidate(int $tenantId): void {
        $dir = sys_get_temp_dir() . '/permedjat-payroll-cache';
        if (!is_dir($dir)) return;
        $prefix = "live_{$tenantId}_";
        foreach (glob("$dir/{$prefix}*.json") ?: [] as $f) {
            @unlink($f);
        }
    }
}
