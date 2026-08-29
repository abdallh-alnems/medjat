-- Break requests: free-text `type` + general hourly salary deduction
-- 1) `type` becomes a free-text label entered by the user (no fixed list).
-- 2) `deduct_from_salary` (hourly deduction) is no longer limited to the
--    early-leave type; it can be chosen for any request at creation and/or
--    adjusted by the approving manager.
-- Created: 2026-06-09
-- Hand-written for live MySQL 8 (no `MODIFY COLUMN IF EXISTS`).

ALTER TABLE `break_requests`
  MODIFY `type` varchar(100)
    COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT ''
    COMMENT 'نوع/وصف الطلب يُدخله المستخدم بحرية';

ALTER TABLE `break_requests`
  MODIFY `deduct_from_salary` tinyint(1) NOT NULL DEFAULT 0
    COMMENT 'هل يُخصم من الراتب بنظام الساعة؟ يُحدَّد عند الإنشاء أو الموافقة';
