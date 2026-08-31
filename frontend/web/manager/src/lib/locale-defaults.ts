import type { TKey } from "@/lib/i18n/ar";

/**
 * Company locale settings shared by onboarding and company settings, so the two
 * forms cannot drift apart.
 *
 * These are chosen once when the company is created. Getting the timezone wrong
 * is not cosmetic — attendance times are stamped on the company's clock, so a
 * wrong zone shifts every check-in and silently distorts lateness and overtime.
 */

export const CURRENCIES = [
  "EGP",
  "SAR",
  "AED",
  "USD",
  "EUR",
  "KWD",
  "QAR",
] as const;

/** Saturday-first ordering to match the Arab work week, ISO weekday → label key. */
export const WEEKDAYS: { value: number; key: TKey }[] = [
  { value: 6, key: "weekday_sat" },
  { value: 7, key: "weekday_sun" },
  { value: 1, key: "weekday_mon" },
  { value: 2, key: "weekday_tue" },
  { value: 3, key: "weekday_wed" },
  { value: 4, key: "weekday_thu" },
  { value: 5, key: "weekday_fri" },
];

const FALLBACK_ZONES = [
  "Africa/Cairo",
  "Asia/Riyadh",
  "Asia/Dubai",
  "Asia/Kuwait",
  "Asia/Qatar",
  "Europe/London",
  "America/New_York",
  "UTC",
];

/** The full IANA list when the browser exposes it, otherwise a regional subset. */
export function supportedZones(current?: string): string[] {
  let zones: string[] = [];
  try {
    const supported = (
      Intl as unknown as { supportedValuesOf?: (k: string) => string[] }
    ).supportedValuesOf;
    if (supported) zones = supported("timeZone");
  } catch {
    /* ignore */
  }
  if (zones.length === 0) zones = [...FALLBACK_ZONES];
  if (current && !zones.includes(current)) zones = [current, ...zones];
  return zones;
}

/** The browser's own timezone, or Cairo when it cannot be read. */
export function detectTimezone(): string {
  try {
    return Intl.DateTimeFormat().resolvedOptions().timeZone || "Africa/Cairo";
  } catch {
    return "Africa/Cairo";
  }
}

const ZONE_CURRENCY: Record<string, (typeof CURRENCIES)[number]> = {
  "Africa/Cairo": "EGP",
  "Asia/Riyadh": "SAR",
  "Asia/Dubai": "AED",
  "Asia/Kuwait": "KWD",
  "Asia/Qatar": "QAR",
};

/**
 * A first guess at the currency from the timezone. Only a prefill — the admin
 * sees it in the form and can change it before submitting.
 */
export function currencyForZone(zone: string): (typeof CURRENCIES)[number] {
  return ZONE_CURRENCY[zone] ?? "EGP";
}

/** Gulf and Egypt start the week on Saturday; elsewhere assume Monday. */
export function weekStartForZone(zone: string): number {
  return zone.startsWith("Africa/") || zone.startsWith("Asia/") ? 6 : 1;
}
