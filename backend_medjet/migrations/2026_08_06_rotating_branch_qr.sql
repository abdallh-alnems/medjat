-- ============================================================
-- Migration: rotating branch QR — a code that is only worth having on the spot
-- Date: 2026-08-06
-- ============================================================
--
-- THE PROBLEM THIS CLOSES
--
-- `branches.qr_code` is a permanent value printed once and taped to a wall. It
-- never changes, so possessing it proves nothing about where the holder is or
-- when they got it: one employee photographs the sheet, the picture reaches a
-- WhatsApp group, and every colleague now carries the branch's credential
-- indefinitely.
--
-- The geofence is what stops that becoming check-in-from-home, and it works —
-- GpsService rejects a punch outside the radius, and rejects the punch outright
-- when the branch has no coordinates configured, precisely so a QR code can
-- never pass unverified. What the geofence CANNOT do is tell "at the door" from
-- "nearby": DEFAULT_GPS_RADIUS is 100 metres, which is a 200-metre-wide circle
-- covering the café next door, the flat upstairs, the car park and the street.
-- Add ordinary GPS drift between buildings and the circle is effectively larger.
--
-- So the division of labour is: GPS answers "roughly in this area?", and the QR
-- is supposed to answer "at this exact point?". A static QR fails at its half
-- the moment it is photographed, and qr_gps quietly degrades into gps_only while
-- still being sold as two factors. A rotating code restores the second factor,
-- because the only way to hold a current one is to be looking at the screen.
--
-- THE TRAP THIS TABLE IS SHAPED AROUND
--
-- The obvious move is to copy face_challenges, which already implements exactly
-- this pattern — nonce, expires_at, consumed_at, expiry computed in SQL. It
-- cannot be reused, for two reasons that matter:
--
--   1) face_challenges.employee_id identifies who the challenge was minted for.
--      A branch code is minted before anyone has scanned it, and there is no
--      branch_id on that table.
--
--   2) MORE IMPORTANTLY: a face challenge is single-use because it belongs to
--      one employee. A branch code is scanned by FORTY employees inside the same
--      thirty seconds. Carrying `consumed_at` across verbatim would mean the
--      first person to scan burns the code and the other thirty-nine are
--      refused — the feature would take the branch down every morning.
--
-- Hence two tables. The code is valid for a window, for everybody; a SEPARATE
-- row records that a given employee has spent a given code. The UNIQUE key on
-- (challenge_id, employee_id) is the atomic claim: a replay collides on insert,
-- so two concurrent requests can never both succeed, and no SELECT-then-INSERT
-- race exists to lose.
--
-- OVERLAPPING WINDOWS ARE INTENTIONAL. The display asks for a fresh code every
-- ROTATE_SECONDS but each code lives TTL_SECONDS, with TTL comfortably longer
-- than the rotation. A single-window design has a guaranteed race: the code
-- rendered at 29.9s expires while the camera is still focusing, and the employee
-- gets a failure they cannot act on. A handful of concurrently valid codes is a
-- rounding error next to a permanent one.
--
-- All expiry arithmetic happens in SQL. PHP runs UTC on this server while MySQL
-- runs the server zone, so a PHP-built timestamp is born hours wrong — the
-- lesson face_challenges paid for.

-- ------------------------------------------------------------
-- 1) branch_qr_challenges — the codes a branch display has shown
-- ------------------------------------------------------------
CREATE TABLE `branch_qr_challenges` (
  `id`         bigint unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id`  int unsigned NOT NULL,
  `branch_id`  int unsigned NOT NULL,
  `nonce`      char(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL
               COMMENT '32 random bytes hex. This is the value encoded in the displayed QR.',
  `expires_at` datetime NOT NULL
               COMMENT 'Computed by MySQL (DATE_ADD(NOW(), ...)), never by PHP.',
  `issued_by`  int unsigned DEFAULT NULL COMMENT 'admins.id that opened the display',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_branch_qr_nonce` (`nonce`),
  -- The verification lookup: this nonce, this branch, not yet expired.
  KEY `idx_branch_qr_lookup` (`branch_id`,`expires_at`),
  KEY `idx_branch_qr_purge` (`expires_at`),
  CONSTRAINT `branch_qr_challenges_tenant_fk` FOREIGN KEY (`tenant_id`)
    REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `branch_qr_challenges_branch_fk` FOREIGN KEY (`branch_id`)
    REFERENCES `branches` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 2) branch_qr_uses — which employee has already spent which code
-- ------------------------------------------------------------
-- Deliberately not a `consumed_at` column on the table above: see the note on
-- the forty employees. ON DELETE CASCADE means the purge of spent challenges
-- takes its use rows with it and this table cannot grow without bound.
CREATE TABLE `branch_qr_uses` (
  `id`           bigint unsigned NOT NULL AUTO_INCREMENT,
  `challenge_id` bigint unsigned NOT NULL,
  `employee_id`  int unsigned NOT NULL,
  `purpose`      enum('check_in','check_out') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
                 NOT NULL DEFAULT 'check_in'
                 COMMENT 'An employee arriving and leaving inside one window is legitimate; the same purpose twice is not.',
  `used_at`      timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  -- The atomic claim. A replayed code fails on INSERT rather than on a prior
  -- SELECT, so concurrent requests cannot both win.
  UNIQUE KEY `uniq_branch_qr_use` (`challenge_id`,`employee_id`,`purpose`),
  KEY `idx_branch_qr_use_emp` (`employee_id`),
  CONSTRAINT `branch_qr_uses_challenge_fk` FOREIGN KEY (`challenge_id`)
    REFERENCES `branch_qr_challenges` (`id`) ON DELETE CASCADE,
  CONSTRAINT `branch_qr_uses_employee_fk` FOREIGN KEY (`employee_id`)
    REFERENCES `employees` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 3) branches.rotating_qr_enabled — off, per branch
-- ------------------------------------------------------------
-- DEFAULT 0, and the switch is per branch rather than per company, because
-- turning it on has a physical prerequisite: a screen at that door. A company
-- with ten branches and one tablet must be able to run rotating codes at the
-- branch that has the tablet without locking the other nine out.
--
-- NO APP RELEASE IS NEEDED. The employee app scans a QR and forwards its raw
-- contents (scan_qr_screen.dart -> processQrScan -> 'qr_code'); it has never
-- interpreted the value. Builds already in the stores therefore send a rotating
-- code exactly as they sent the printed one, and the server decides which it
-- expects. That is why the flag can be flipped per branch on its own schedule.
--
-- ⚠️ IT DOES NOT SURVIVE OFFLINE MODE, and this is the one thing to understand
-- before enabling it. A queued punch syncs through app/attendance/sync_offline.php,
-- which writes with method 'offline' and evaluates no QR and no geofence — as it
-- already did for the printed code. So an employee who turns off mobile data can
-- punch without any code at all, and the queue will be accepted later.
--
-- That is pre-existing behaviour, not something this feature introduces, but it
-- bounds what the feature is worth: a branch that wants the rotating code to
-- MEAN anything should also set allow_offline_attendance = 0, on the branch or
-- the company. Left on, this raises the effort of cheating without closing it.
ALTER TABLE `branches`
  ADD COLUMN `rotating_qr_enabled` tinyint(1) NOT NULL DEFAULT 0
    COMMENT 'Require a time-limited code from a branch display instead of the printed branches.qr_code.';
