-- ============================================================
-- Migration: branch kiosk — per-branch settings and employee fallback code
-- Date: 2026-08-03
-- Feature: specs/005-branch-kiosk
-- ============================================================
--
-- Additive only. Nothing is dropped or narrowed.
--
-- ---- What is REUSED from the old station system (already live) --------------
--
--   branches.station_enabled                 -> whether the kiosk is on for this branch
--   branches.station_gps_radius_meters (30)  -> the tablet is fixed; this is a sanity check
--   branches.station_anti_spoofing_enabled   -> whether liveness failure refuses or only flags
--
-- ---- What CANNOT be reused, and why -----------------------------------------
--
--   branches.station_confidence_threshold  decimal(3,2)
--       Two decimal places. Every other threshold in this system is
--       decimal(4,3) (tenants.face_match_threshold, branches.face_match_threshold,
--       face_verification_logs.threshold). A 1:N operating point needs the third
--       digit. Left in place, unused.
--
--   branches.station_methods  enum('face_only','fingerprint_only','both_available')
--       The fingerprint options assume hardware a tablet does not have. Platform
--       biometric APIs (Android BiometricPrompt, iOS LocalAuthentication)
--       authenticate the DEVICE OWNER and return a boolean; they cannot enrol or
--       identify a third party, and cheap tablets mostly have no sensor at all.
--       The archived removal migration flagged this in 2026-06 and it is still
--       true. Left in place, unused.
--
--   branches.station_admin_pin_hash
--       Built for a STATIC per-branch PIN. Superseded by kiosk_codes, which
--       issues a single-use short-lived code from the management app — strictly
--       stronger, because a static PIN is shared once and works forever.
--       Left in place, unused.
--
-- MySQL 8: no "ADD COLUMN IF NOT EXISTS". Run once, in order.

-- ------------------------------------------------------------
-- 1) branches — kiosk matching parameters
-- ------------------------------------------------------------
-- NULL means "fall back to the system default" rather than a hardcoded number,
-- so the starting operating point can be retuned centrally after the first real
-- branch has produced data. Starting points: threshold 0.550, margin 0.080 —
-- both stricter than the 0.450 used for 1:1 selfie verification, because
-- false-accept risk compounds across a roster.
ALTER TABLE `branches`
  ADD COLUMN `station_match_threshold` decimal(4,3) DEFAULT NULL
    COMMENT 'Kiosk 1:N absolute threshold; NULL = system default. Stricter than 1:1 selfie matching',
  ADD COLUMN `station_match_margin` decimal(4,3) DEFAULT NULL
    COMMENT 'Required gap between best and runner-up candidate; NULL = system default. This is what makes 1:N safe',
  ADD COLUMN `station_code_fallback_enabled` tinyint(1) NOT NULL DEFAULT '1'
    COMMENT 'Whether the per-employee code path is offered at this branch kiosks';

-- ------------------------------------------------------------
-- 2) employees — kiosk fallback code and enrollment provenance
-- ------------------------------------------------------------
-- The code is a PER-EMPLOYEE fallback for the day a face will not resolve — a
-- mask, a bandage, bad light. It is never a company-wide substitute for face
-- identification: a code can be handed to a colleague, which is precisely the
-- abuse this whole feature exists to resist.
--
-- Hashed, never recoverable. Shown once when issued or reset.
--
-- Face enrollment itself reuses the columns that already exist on this table
-- (face_embedding, face_model_version, face_embedding_dim, face_enrolled_at,
-- face_quality_score, face_photo_url) — an enrollment captured at a kiosk IS
-- the enrollment a selfie punch matches against, not a parallel one.
ALTER TABLE `employees`
  ADD COLUMN `kiosk_pin_hash` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL
    COMMENT 'Per-employee kiosk fallback code, hashed; plaintext shown once at issue',
  ADD COLUMN `kiosk_pin_set_at` datetime DEFAULT NULL,
  ADD COLUMN `face_enrolled_by_station_id` int unsigned DEFAULT NULL
    COMMENT 'Which kiosk performed the enrollment, if any — provenance for an enrollment nobody watched';
