-- Early-leave permission (إذن انصراف مبكر) for break_requests
-- Adds the `early_leave` type and a `deduct_from_salary` flag the approving
-- manager sets to decide whether the early-leave window is deducted from the
-- salary by the hourly rate.
-- Created: 2026-06-08
-- Hand-written for live MySQL 8 (no `ADD COLUMN IF NOT EXISTS`).

ALTER TABLE `break_requests`
  MODIFY `type` enum('break','permission','prayer','errand','medical','early_leave','other')
    COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'break';

ALTER TABLE `break_requests`
  ADD COLUMN `deduct_from_salary` tinyint(1) NOT NULL DEFAULT 0
    COMMENT 'إذن انصراف مبكر: هل يُخصم بنظام الساعة من الراتب؟ يحدده المدير عند الموافقة'
    AFTER `type`;
