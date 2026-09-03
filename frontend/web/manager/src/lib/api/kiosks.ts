import { apiPost } from "./client";

/**
 * Branch kiosks — the shared tablets employees clock in on.
 *
 * Not to be confused with `devices.ts`, which handles third-party fingerprint
 * terminals. A kiosk runs Permedjat's own app and authenticates as a **branch**,
 * so a kiosk credential can record attendance for anyone enrolled there. That
 * is why pairing, revoking, and viewing captures are three separate
 * permissions rather than one.
 *
 * Everything is POST, including the reads: writes require POST on this backend
 * and the reads stay consistent with their neighbours.
 */

export interface KioskStation {
  id: number;
  name: string | null;
  status: "active" | "revoked";
  branch: { id: number; name: string };
  device_model: string | null;
  app_version: string | null;
  /** Raising the minimum version would take this tablet out of service. */
  below_min_version: boolean;
  last_seen_at: string | null;
  is_offline: boolean;
  punch_count: number;
  last_punch_at: string | null;
  paired_at: string | null;
  revoked_at: string | null;
}

export interface KioskRoster {
  branch_id: number;
  branch_name: string;
  enrolled: number;
  warn_above: number;
  /** Past the roster size at which face-only identification stays accurate. */
  over_ceiling: boolean;
}

export interface KioskListResponse {
  stations: KioskStation[];
  rosters: KioskRoster[];
  min_version: string;
  /** How many active tablets a version raise would stop. */
  would_block_count: number;
  /** The gate was answered from cache because Remote Config was unreachable. */
  version_gate_stale: boolean;
}

export function listKiosks(branchId?: number) {
  return apiPost<KioskListResponse>("v1/kiosk/stations", {
    ...(branchId ? { branch_id: branchId } : {}),
  });
}

/**
 * Issues a pairing code.
 *
 * The plaintext is returned **once** — the server stores only its hash — so it
 * must be shown immediately and never cached or re-fetched.
 */
export function createKioskPairingCode(branchId: number, name?: string) {
  return apiPost<{ code: string; expires_at: string; branch: { id: number; name: string } }>(
    "v1/kiosk/pairing-code",
    { branch_id: branchId, ...(name ? { name } : {}) },
  );
}

/** Opens a kiosk's settings on the tablet. Six digits, five minutes, single use. */
export function createKioskAccessCode(stationId: number) {
  return apiPost<{ code: string; expires_at: string }>(
    "v1/kiosk/access-code",
    { station_id: stationId },
  );
}

/**
 * Takes a tablet out of service.
 *
 * Effective on the device's next request — a switched-off tablet cannot be
 * told anything — and the station row survives, because historical attendance
 * points at it.
 */
export function revokeKiosk(stationId: number, reason?: string) {
  return apiPost<{ station_id: number; status: string }>(
    "v1/kiosk/revoke",
    { station_id: stationId, ...(reason ? { reason } : {}) },
  );
}

export interface KioskAttempt {
  id: number;
  created_at: string;
  branch: { id: number; name: string };
  station: { id: number; name: string | null };
  employee: { id: number; name: string } | null;
  purpose: string;
  method: "face" | "code";
  result: string;
  accepted: boolean;
  match_score: number | null;
  /** The second-best candidate — meaningless to omit in a one-to-many decision. */
  runner_up: number | null;
  margin_gap: number | null;
  threshold: number | null;
  margin: number | null;
  candidates: number | null;
  liveness_passed: boolean;
  attendance_id: number | null;
  has_capture: boolean;
}

export function listKioskAttempts(params: {
  branchId?: number;
  stationId?: number;
  result?: string;
  limit?: number;
}) {
  return apiPost<{ logs: KioskAttempt[] }>("v1/kiosk/recognition-logs", {
    view: "list",
    ...(params.branchId ? { branch_id: params.branchId } : {}),
    ...(params.stationId ? { station_id: params.stationId } : {}),
    ...(params.result ? { result: params.result } : {}),
    limit: params.limit ?? 100,
  });
}

export interface KioskScoreBucket {
  bucket: number;
  result: string;
  attempts: number;
  avg_runner_up: number | null;
  avg_candidates: number | null;
}

/**
 * The histogram the matching threshold is chosen from.
 *
 * The shipped defaults come from a public face dataset, not from this
 * company's branch — a tenant that never reads this is running on somebody
 * else's numbers.
 */
export function kioskScoreDistribution(branchId?: number) {
  return apiPost<{
    buckets: KioskScoreBucket[];
    summary: {
      matched_attempts: number;
      rejected_attempts: number;
      current_defaults: { threshold: number; margin: number };
    };
  }>("v1/kiosk/recognition-logs", {
    view: "distribution",
    ...(branchId ? { branch_id: branchId } : {}),
  });
}

/** Costs `kiosk_evidence`, and every call is written to the audit log. */
export function kioskCapture(recognitionLogId: number) {
  return apiPost<{ image_base64: string; captured_at: string; expires_at: string }>(
    "v1/kiosk/capture",
    { recognition_log_id: recognitionLogId },
  );
}

/** Issues or clears an employee's personal fallback code. Plaintext once. */
export function setEmployeeKioskCode(employeeId: number, clear = false) {
  return apiPost<{ code?: string; has_code: boolean }>(
    "v1/kiosk/set-pin",
    { employee_id: employeeId, ...(clear ? { clear: true } : {}) },
  );
}
