-- ============================================================
-- Migration: crew attendance — a supervisor records the people with them
-- Date: 2026-08-06
-- ============================================================
--
-- THE GAP
--
-- Every self-service method Permedjat has assumes the worker is holding a working
-- smartphone with the app on it. A construction site with thirty labourers has
-- one of those, and it belongs to the foreman. The kiosk does not help either:
-- it needs a fixed tablet, mains power and a door, and a site has none of them.
--
-- So today those companies have exactly one option — an administrator typing
-- thirty names into `manual` from an office, with no evidence anybody was ever
-- on site. This method is that same act performed AT the site, with coordinates,
-- a photograph, and the name of the person who did it.
--
-- ------------------------------------------------------------
-- 1) employees.crew_supervisor_id — who records for this person
-- ------------------------------------------------------------
-- A self-reference rather than a `crews` + `crew_members` pair, and rather than
-- reusing employee_categories.
--
-- Categories were the obvious candidate and are the wrong shape: an employee
-- belongs to SEVERAL of them and they already carry attendance-method semantics
-- (unioned across categories). Overloading them with "and also this is a crew"
-- would make two unrelated things move together.
--
-- More importantly this column removes a flag that would otherwise have to
-- exist. There is no `is_crew_supervisor` boolean, because being a supervisor is
-- not an independent fact — it is "somebody points at me". A separate flag could
-- disagree with reality in both directions: set with an empty crew, or cleared
-- while ten people still point at you. Deriving it cannot drift.
--
-- It also makes the authorisation check the same sentence as the question the
-- endpoint is asking: may I record for this person? Only if their
-- crew_supervisor_id is me.
--
-- NULL for everybody on deploy, so this changes nothing until a company fills it in.
ALTER TABLE `employees`
  ADD COLUMN `crew_supervisor_id` int unsigned DEFAULT NULL
    COMMENT 'employees.id of the supervisor who may record this person attendance on site. NULL = nobody.',
  ADD KEY `idx_emp_crew_supervisor` (`crew_supervisor_id`,`tenant_id`),
  ADD CONSTRAINT `employees_crew_supervisor_fk` FOREIGN KEY (`crew_supervisor_id`)
    REFERENCES `employees` (`id`) ON DELETE SET NULL;

-- NO CHECK CONSTRAINT HERE, and not for want of trying. The obvious guard —
-- CHECK (crew_supervisor_id IS NULL OR crew_supervisor_id <> id) — is rejected
-- by MySQL 8:
--
--   ERROR 3823: Column 'crew_supervisor_id' cannot be used in a check
--   constraint: needed in a foreign key constraint referential action.
--
-- A column cannot be both written by ON DELETE SET NULL and constrained by a
-- CHECK. Of the two, SET NULL is the one worth keeping: when a supervisor
-- leaves the company their crew's pointers should clear themselves rather than
-- block the deletion or dangle.
--
-- So cycle prevention lives entirely in CrewModel::wouldCycle(), which has to
-- exist regardless — a CHECK can only see its own row, and the loop that
-- actually matters is A supervises B supervises A, which spans two.


-- ------------------------------------------------------------
-- 2) attendance.recorded_by_employee_id — a colleague, not an administrator
-- ------------------------------------------------------------
-- `attendance.recorded_by` already exists and already means "who recorded this",
-- but its foreign key points at `admins`. Every employee does happen to have a
-- shadow admins row (employee_login.php creates one with firebase_uid
-- 'employee:<id>'), so reusing it would technically work — and would quietly
-- merge two different principals into one column, so that "an administrator
-- entered this from the office" and "a colleague marked me present on a
-- building site" became indistinguishable without also reading the method.
--
-- Those two carry very different weight in a dispute. They get different columns.
ALTER TABLE `attendance`
  ADD COLUMN `recorded_by_employee_id` int unsigned DEFAULT NULL
    COMMENT 'employees.id of the supervisor who recorded this on site. Distinct from recorded_by, which is an administrator.',
  ADD COLUMN `crew_photo` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL
    COMMENT 'Relative path under uploads/attendance/. One group photograph shared by every row in the batch. Evidence for a human — never scored, never matched.',
  ADD KEY `idx_att_recorded_by_employee` (`recorded_by_employee_id`),
  ADD CONSTRAINT `attendance_recorded_by_employee_fk` FOREIGN KEY (`recorded_by_employee_id`)
    REFERENCES `employees` (`id`) ON DELETE SET NULL;

-- ------------------------------------------------------------
-- 3) tenants.crew_photo_required
-- ------------------------------------------------------------
-- DEFAULT 0, the opposite of the browser channel's photo default, and for a
-- reason specific to where this is used. A browser punch happens at a desk, so
-- demanding a photograph costs nothing. A foreman photographs thirty people in
-- direct sun with dusty hands and one bar of signal; making that mandatory on
-- day one is how a company decides the feature is not worth using.
--
-- Companies that want the evidence turn it on knowingly.
ALTER TABLE `tenants`
  ADD COLUMN `crew_photo_required` tinyint(1) NOT NULL DEFAULT 0
    COMMENT 'Require a group photograph on every crew attendance batch.';

-- ------------------------------------------------------------
-- 4) enum widening
-- ------------------------------------------------------------
-- Values read from PRODUCTION on 2026-08-06 (after that day's photo_gps and
-- rotating-QR deploy), not from the last migration that touched them — see the
-- note in 2026_08_06_restore_web_security_log_reasons.sql for what that
-- distinction cost this codebase.
ALTER TABLE `attendance`
  MODIFY COLUMN `check_in_method` enum(
    'qr_gps','gps_only','qr_gps_face','face_selfie','wifi_gps','photo_gps',
    'crew_gps',
    'device','manual','kiosk','offline'
  ) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'qr_gps';

ALTER TABLE `attendance`
  MODIFY COLUMN `check_out_method` enum(
    'qr_gps','gps_only','qr_gps_face','face_selfie','wifi_gps','photo_gps',
    'crew_gps',
    'device','manual','kiosk','offline','auto'
  ) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL;

-- 'crew_not_supervisor' is the refusal that matters here: somebody asked to
-- record attendance for a person who is not in their crew. Innocently that is a
-- stale app list after a reassignment; deliberately it is an employee trying to
-- mark a colleague present. Either way the company should be able to see it.
ALTER TABLE `attendance_security_logs`
  MODIFY COLUMN `reason` enum(
    'mock_location','rooted','jailbroken','vpn','gps_out_of_range','no_local_biometric',
    'kiosk_ambiguous_match','kiosk_spoofing_suspected','kiosk_out_of_branch',
    'kiosk_pin_bruteforce','kiosk_revoked_token','kiosk_version_blocked',
    'web_not_permitted','web_pin_locked','web_shared_device',
    'qr_replayed','qr_expired',
    'crew_not_supervisor'
  ) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL;
