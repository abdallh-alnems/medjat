-- ============================================================
-- Migration: catch a replayed face embedding
-- Date: 2026-08-06
-- Closes: the one hole open in shipped code (register item b-1)
-- ============================================================
--
-- THE HOLE
--
-- The phone extracts the face embedding and the SERVER scores it — a deliberate
-- decision, and the right one. But the server never sees the image, so it is
-- trusting the phone about where those numbers came from:
--
--   FaceMatchService::verify()
--     $livenessPassed = !empty($input['liveness_passed']);   // a boolean from the client
--     $candidate      = parseEmbedding($input['face_embedding']);  // 192 floats from the client
--
-- A modified build can therefore capture its own embedding once, legitimately,
-- and then post those same numbers every morning with liveness_passed = true,
-- from anywhere, without ever opening the camera.
--
-- The single-use nonce does not stop this. It prevents replaying the same
-- REQUEST; it says nothing about the numbers inside a fresh one. Nothing binds
-- the challenge to the capture.
--
-- WHAT CATCHES IT
--
-- A real face never produces the same numbers twice. Lighting shifts, the head
-- tilts a degree, the distance changes — every genuine capture differs. So an
-- embedding IDENTICAL to one this employee sent before did not come from a
-- camera. It was read from storage.
--
-- WHY A HASH AND NOT THE EMBEDDING ITSELF
--
-- The obvious implementation stores recent embeddings and compares each new one
-- by cosine similarity. That was rejected: it would multiply the biometric
-- material this product deliberately minimises. The whole privacy posture here
-- is that the image never leaves the phone and only one template per employee is
-- kept; storing every ATTEMPT's template would quietly undo that, and under law
-- 14/2025 it is exactly the kind of accumulation that needs justifying.
--
-- A hash proves "identical" without holding anything reversible.
--
-- The embedding is quantised (4 decimals) before hashing, for representation
-- stability rather than security: the same capture can arrive as a float, as a
-- string, or via a JSON round trip, and full-precision printing does not always
-- produce identical text. Without rounding an honest replay could hash
-- differently and slip past — a false negative, which is the failure that
-- actually matters in a detector.
--
-- HONEST LIMIT, measured rather than assumed: quantisation does NOT stop an
-- attacker who adds noise. Perturbing every component by 1e-6 already changes
-- the fingerprint, because across 192 components some sit near a rounding
-- boundary and flip. A hash can only ever answer "identical", never "similar".
--
-- So the scope of this check is: a build that stores an embedding and posts it
-- back verbatim — which is exactly what a downloaded modified APK does, and the
-- realistic threat here. Someone hand-editing float arrays evades it. The layer
-- for that is Firebase App Check, which stops an unattested build from talking
-- to the server at all, and which is already a paid dependency in pubspec.yaml
-- with no code calling it.
--
-- Catching the noise case in this layer would mean storing recent embeddings and
-- comparing by cosine similarity — rejected above on privacy grounds, and it
-- only moves the bar rather than closing the hole.

-- ------------------------------------------------------------
-- 1) The fingerprint, stored on the attempt log
-- ------------------------------------------------------------
-- Goes on face_verification_logs rather than a new table because that row
-- already exists for every attempt and already carries the score, the challenge
-- and the outcome. One more column keeps the whole story of an attempt in one
-- place.
ALTER TABLE `face_verification_logs`
  ADD COLUMN `embedding_hash` char(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL
    COMMENT 'SHA-256 of the quantised embedding. One-way: proves two attempts were identical without storing the biometric template again.',
  -- The lookup is an equality probe on (tenant, employee, hash), so this index
  -- is what keeps the check O(1) as the log grows.
  ADD KEY `idx_fvl_replay` (`tenant_id`,`employee_id`,`embedding_hash`);

-- 'replayed_embedding' as an attempt outcome. Existing values restated in full;
-- MySQL 8 has no additive ENUM syntax.
ALTER TABLE `face_verification_logs`
  MODIFY COLUMN `result` enum(
    'matched','below_threshold','liveness_failed','not_enrolled',
    'invalid_challenge','bad_embedding','model_mismatch',
    'replayed_embedding'
  ) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL;

-- ------------------------------------------------------------
-- 2) The security-log reason
-- ------------------------------------------------------------
-- Values read from PRODUCTION on 2026-08-06, after that day's three deploys —
-- not from the last migration that touched this column. Doing it the other way
-- round is what silently deleted three web values earlier today; see
-- 2026_08_06_restore_web_security_log_reasons.sql.
ALTER TABLE `attendance_security_logs`
  MODIFY COLUMN `reason` enum(
    'mock_location','rooted','jailbroken','vpn','gps_out_of_range','no_local_biometric',
    'kiosk_ambiguous_match','kiosk_spoofing_suspected','kiosk_out_of_branch',
    'kiosk_pin_bruteforce','kiosk_revoked_token','kiosk_version_blocked',
    'web_not_permitted','web_pin_locked','web_shared_device',
    'qr_replayed','qr_expired',
    'crew_not_supervisor',
    'replayed_embedding'
  ) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL;

-- ------------------------------------------------------------
-- 3) log_only first — the same discipline the threshold got
-- ------------------------------------------------------------
-- DEFAULT 'log_only', and deliberately a SEPARATE switch from
-- tenants.face_enforce_mode. A company that has finished tuning its threshold
-- and moved to enforce has not thereby agreed to start rejecting on a brand-new
-- signal nobody has seen real data for yet.
--
-- The order to follow is the one the threshold taught this codebase: watch
-- face_verification_logs.result = 'replayed_embedding' for a couple of weeks. If
-- genuine employees appear there, the detection is wrong and must be fixed
-- before it blocks anyone — a false positive here accuses somebody of fraud.
ALTER TABLE `tenants`
  ADD COLUMN `face_replay_mode` enum('log_only','enforce')
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'log_only'
    COMMENT 'What to do when an embedding is identical to an earlier attempt. Starts as log_only for every company.';
