/**
 * A stable identifier for this browser.
 *
 * Used for two things: binding the session to the browser that created it, and
 * noticing when one browser records attendance for more than one employee.
 *
 * It is a plain random id in a long-lived cookie, deliberately not a
 * fingerprint. A fingerprint would survive being cleared, but it is a privacy
 * escalation that sits badly beside the consent obligations attendance data
 * already carries — and the detection it feeds is advisory anyway. Someone who
 * clears it to hide a shared device has to do so before every punch, and the
 * IP correlation is still there.
 */

const COOKIE_NAME = "medjat_emp_device";
const ONE_YEAR_SECONDS = 60 * 60 * 24 * 365;

function readCookie(name: string): string | null {
  if (typeof document === "undefined") return null;
  const match = document.cookie.match(
    new RegExp(`(?:^|; )${name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}=([^;]*)`),
  );
  return match ? decodeURIComponent(match[1]) : null;
}

function newId(): string {
  const webCrypto: Crypto | undefined = typeof crypto !== "undefined" ? crypto : undefined;

  if (typeof webCrypto?.randomUUID === "function") {
    return webCrypto.randomUUID();
  }

  // Older Safari on iOS lacks randomUUID. getRandomValues is far more widely
  // available, and Math.random would make ids collide across devices — which
  // would put two unrelated employees on one "device" and produce a false
  // shared-device flag.
  if (typeof webCrypto?.getRandomValues === "function") {
    const bytes = new Uint8Array(16);
    webCrypto.getRandomValues(bytes);
    return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
  }

  // No secure randomness at all. Rather than fall back to Math.random and hand
  // out ids that can collide, return a value that marks itself as untrusted:
  // the shared-device signal is advisory, so a missing id costs a hint, while a
  // colliding id would accuse two unrelated employees.
  return `nocrypto-${Date.now()}-${Math.random().toString(36).slice(2)}`;
}

/** Returns this browser's id, creating and persisting one on first use. */
export function getDeviceId(): string {
  const existing = readCookie(COOKIE_NAME);
  if (existing) return existing;

  const id = newId();
  const secure = typeof location !== "undefined" && location.protocol === "https:";
  document.cookie =
    `${COOKIE_NAME}=${encodeURIComponent(id)}; path=/; max-age=${ONE_YEAR_SECONDS}; SameSite=Lax` +
    (secure ? "; Secure" : "");

  return id;
}
