import { z } from "zod";
import { getDeviceId } from "./device-id";

/**
 * Employee-side API calls.
 *
 * Everything goes through `/api/employee/*`, which injects the session cookie
 * server-side. Nothing here ever holds the session token, and nothing here
 * imports from the admin tree.
 */

/**
 * Mirrors EmployeeWebCredentialModel::rejectReason so the employee learns what
 * is wrong before a round-trip. The **server** is the control — this is only
 * there so the feedback is instant, and it deliberately omits the phone-number
 * rule, which needs data the page does not have.
 */
export function pinRejectReason(pin: string): string | null {
  if (!/^\d{6}$/.test(pin)) return "length";
  if (/^(\d)\1{5}$/.test(pin)) return "repeated";

  // Runs in either direction — checked structurally, not listed, because a list
  // of "the obvious ones" always misses the run starting one digit over.
  let ascending = true;
  let descending = true;
  for (let i = 1; i < pin.length; i++) {
    const step = Number(pin[i]) - Number(pin[i - 1]);
    if (step !== 1) ascending = false;
    if (step !== -1) descending = false;
  }
  if (ascending || descending) return "sequence";

  for (const block of [2, 3]) {
    if (pin === pin.slice(0, block).repeat(6 / block)) return "pattern";
  }

  const common = [
    "123456", "654321", "012345", "543210",
    "123123", "112233", "121212", "123321", "696969",
    "159753", "147258", "135790", "102030", "123654",
  ];
  return common.includes(pin) ? "common" : null;
}

export const pinSchema = z.string().refine((v) => pinRejectReason(v) === null, "pin_rejected");

export const phoneSchema = z.string().trim().min(6, "phone_required");

export type AttendanceState = "not_checked_in" | "checked_in" | "checked_out";

export interface WebStatus {
  state: AttendanceState;
  check_in_at: string | null;
  check_out_at: string | null;
  check_in_origin: "app" | "web" | null;
  check_out_origin: "app" | "web" | null;
  branch: {
    id: number;
    name: string;
    latitude: number | null;
    longitude: number | null;
    gps_radius_meters: number;
  } | null;
  photo_required: boolean;
  network_constraint: "ip" | "none";
  server_time: string;
}

export class ApiError extends Error {
  constructor(
    message: string,
    readonly code: string | null,
    readonly status: number,
  ) {
    super(message);
  }
}

async function post<T>(path: string, body: Record<string, unknown>): Promise<T> {
  const res = await fetch(path, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });

  const text = await res.text();
  let json: Record<string, unknown> = {};
  try {
    json = text ? JSON.parse(text) : {};
  } catch {
    throw new ApiError("unreadable_response", null, res.status);
  }

  if (!res.ok) {
    throw new ApiError(
      (json.message as string) ?? (json.error as string) ?? "request_failed",
      (json.error_code as string) ?? (json.code as string) ?? null,
      res.status,
    );
  }

  return (json.data ?? json) as T;
}

export function activate(input: { phone: string; activation_code: string; pin: string }) {
  return post<{ employee: unknown; expires_at: string | null }>("/api/employee/session", {
    action: "activate",
    device_id: getDeviceId(),
    ...input,
  });
}

export function login(input: { phone: string; pin: string }) {
  return post<{ employee: unknown; expires_at: string | null }>("/api/employee/session", {
    action: "login",
    device_id: getDeviceId(),
    ...input,
  });
}

export async function logout() {
  await fetch("/api/employee/session", { method: "DELETE" });
}

export function fetchStatus() {
  return post<WebStatus>("/api/employee/app/attendance/web_status.php", {});
}

export function checkIn(input: {
  branch_id: number;
  latitude: number;
  longitude: number;
  photo_base64?: string;
}) {
  return post<{ time: string; branch: string }>(
    "/api/employee/app/attendance/check_in.php",
    input,
  );
}

export function checkOut(input: { latitude?: number; longitude?: number; photo_base64?: string }) {
  return post<{ time: string; session_ended: boolean }>(
    "/api/employee/app/attendance/check_out.php",
    input,
  );
}

/**
 * The browser's position, with the failure cases separated.
 *
 * A refused permission and a device that cannot get a fix need different words:
 * one is fixable by the employee, the other is not, and telling someone to
 * "allow location" when they already did is how support tickets are made.
 */
export function getPosition(): Promise<GeolocationPosition> {
  return new Promise((resolve, reject) => {
    if (typeof navigator === "undefined" || !navigator.geolocation) {
      reject(new ApiError("geolocation_unsupported", "GEO_UNSUPPORTED", 0));
      return;
    }

    navigator.geolocation.getCurrentPosition(resolve, (err) => {
      const code =
        err.code === err.PERMISSION_DENIED
          ? "GEO_DENIED"
          : err.code === err.TIMEOUT
            ? "GEO_TIMEOUT"
            : "GEO_UNAVAILABLE";
      reject(new ApiError(code.toLowerCase(), code, 0));
    }, {
      enableHighAccuracy: true,
      timeout: 20000,
      maximumAge: 0,
    });
  });
}
