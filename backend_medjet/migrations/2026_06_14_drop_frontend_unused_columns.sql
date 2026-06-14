-- Drop columns not used by any frontend app (2026-06-14)
-- Setup-phase cleanup: these columns were never surfaced in the Flutter apps.
-- Backend code that referenced them has been updated/removed accordingly.
-- No indexes or foreign keys depend on these columns.

ALTER TABLE tenants
  DROP COLUMN logo_url,
  DROP COLUMN stamp_url,
  DROP COLUMN signature_url;

ALTER TABLE admins
  DROP COLUMN password_hash;

ALTER TABLE employees
  DROP COLUMN deleted_at,
  DROP COLUMN face_photo_url,
  DROP COLUMN fingerprint_template;

ALTER TABLE attendance
  DROP COLUMN check_out_latitude,
  DROP COLUMN check_out_longitude;

ALTER TABLE attendance_stations
  DROP COLUMN deactivated_at,
  DROP COLUMN last_sync_at,
  DROP COLUMN locked_at;

ALTER TABLE approval_chains
  DROP COLUMN max_amount;

ALTER TABLE leave_year_balances
  DROP COLUMN carryover_expires_on;

ALTER TABLE payroll_statutory_settings
  DROP COLUMN si_employer_rate;

ALTER TABLE station_recognition_logs
  DROP COLUMN captured_image_path;

ALTER TABLE super_admin_audit_log
  DROP COLUMN user_agent;

-- plans.price: legacy/redundant — real pricing uses monthly_price / annual_price.
ALTER TABLE plans
  DROP COLUMN price;

-- tenants.domain: captured on tenant create but never meaningfully read
-- (findByDomain() was dead code; only a mislabeled company.php mapping read it).
ALTER TABLE tenants
  DROP COLUMN domain;
