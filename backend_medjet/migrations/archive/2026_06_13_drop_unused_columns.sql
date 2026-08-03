-- Drop unused columns (2026-06-13)
-- None of these columns are referenced by any application code (PHP or Dart);
-- they appear only in schema/seed SQL. Verified via full-repo search.

ALTER TABLE admins
  DROP COLUMN two_factor_enabled,
  DROP COLUMN two_factor_secret;

ALTER TABLE super_admins
  DROP COLUMN two_factor_enabled,
  DROP COLUMN two_factor_secret;

ALTER TABLE subscriptions
  DROP COLUMN auto_renew,
  DROP COLUMN payment_method;

ALTER TABLE tenants
  DROP COLUMN trial_ends_at,
  DROP COLUMN attendance_method;

ALTER TABLE branches
  DROP COLUMN attendance_method;

ALTER TABLE payroll
  DROP COLUMN late_total_minutes,
  DROP COLUMN leave_days;

ALTER TABLE analytics_dashboards
  DROP COLUMN is_default;

ALTER TABLE attendance
  DROP COLUMN is_rooted_device;

ALTER TABLE holidays
  DROP COLUMN is_paid;

ALTER TABLE survey_responses
  DROP COLUMN submitted_at;
