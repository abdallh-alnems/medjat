-- ============================================
-- Migration: per-company requirement for a device-biometric gate on self check-in
-- Date: 2026-07-31
-- ============================================
--
-- The hole this closes is the ordinary one, not the exotic one: an employee
-- hands their unlocked, already-signed-in phone to a colleague, who taps the
-- check-in button for them. Every existing control passes — the token is valid,
-- the device is the enrolled one, the GPS is inside the geofence, the WiFi is
-- the branch router. Nothing in the request is false except who pressed it.
--
-- The gate is the phone's own fingerprint/FaceID, required at the moment of the
-- tap. A colleague holding the phone cannot pass it unless their biometric is
-- also enrolled on that handset.
--
-- Note this is enrolment-of-the-handset, not identity: it proves whoever tapped
-- can unlock this phone. That is precisely the buddy-punching case and nothing
-- more. `face_selfie` remains the control that proves *who*.
--
-- HONEST LIMIT, read before selling this to a customer: `local_biometric` is
-- client-reported, exactly like `is_mock_location`. A patched APK can send 1
-- without ever prompting. It is not proof; it raises the cost of cheating from
-- "hand your phone over" to "install a modified APK", which is a different
-- population of people. Companies wanting a server-verified identity need
-- face_selfie.
--
-- DEFAULT 0, so deploying this changes nothing for existing companies; each one
-- opts in from company settings. Older app builds do not send the field, so
-- enabling it before the app update ships would lock everyone out — the
-- endpoints therefore reject only when the tenant has opted in.
--
-- MySQL 8 (live) has no "ADD COLUMN IF NOT EXISTS" — run once by hand.

ALTER TABLE `tenants`
  ADD COLUMN `require_local_biometric` tinyint(1) NOT NULL DEFAULT 0
  COMMENT 'Require the phone fingerprint/FaceID gate on self check-in and check-out'
  AFTER `reject_mock_location`;

-- `no_local_biometric` is a new refusal reason. Re-listing the existing values
-- is required: MODIFY replaces the enum definition wholesale, so omitting one
-- would silently invalidate every row already holding it.
ALTER TABLE `attendance_security_logs`
  MODIFY COLUMN `reason` enum(
    'mock_location',
    'rooted',
    'jailbroken',
    'vpn',
    'gps_out_of_range',
    'no_local_biometric'
  ) COLLATE utf8mb4_unicode_ci NOT NULL;
