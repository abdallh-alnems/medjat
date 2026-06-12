-- ============================================================
-- Migration: distinct 'rejected' status for employee_loans
-- Date: 2026-06-11
-- A manager rejecting a pending advance request used to fall back
-- to 'cancelled', which is indistinguishable from the employee
-- withdrawing their own request. Add a dedicated 'rejected' state
-- so the employee's history clearly shows a rejection.
-- ============================================================

ALTER TABLE `employee_loans`
  MODIFY COLUMN `status` enum('pending','active','completed','cancelled','rejected')
  COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending';
