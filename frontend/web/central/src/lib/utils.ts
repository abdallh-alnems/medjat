import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

/** Format a number as EGP currency. Uses Arabic-Indic digits when locale is ar. */
export function formatEGP(
  amount: number | null | undefined,
  locale: "ar" | "en" = "ar",
): string {
  if (amount === null || amount === undefined || Number.isNaN(amount)) {
    return "—";
  }
  const localeTag = locale === "ar" ? "ar-EG" : "en-EG";
  return new Intl.NumberFormat(localeTag, {
    style: "currency",
    currency: "EGP",
    maximumFractionDigits: 2,
  }).format(amount);
}

/** Format a date (ISO/Date/YYYY-MM-DD) for display. */
export function formatDate(
  date: string | Date | null | undefined,
  locale: "ar" | "en" = "ar",
  options?: Intl.DateTimeFormatOptions,
): string {
  if (!date) return locale === "ar" ? "—" : "—";
  let d: Date;
  if (typeof date === "string") {
    if (/^\d{4}-\d{2}-\d{2}$/.test(date)) {
      const [y, m, day] = date.split("-").map(Number);
      d = new Date(y, m - 1, day);
    } else {
      d = new Date(date);
    }
  } else {
    d = date;
  }
  if (Number.isNaN(d.getTime())) return "—";
  const localeTag = locale === "ar" ? "ar-EG" : "en-GB";
  return new Intl.DateTimeFormat(
    localeTag,
    options ?? { year: "numeric", month: "short", day: "numeric" },
  ).format(d);
}

/** Format a plain number with grouping and optional Arabic-Indic digits. */
export function formatNumber(
  value: number | null | undefined,
  locale: "ar" | "en" = "ar",
): string {
  if (value === null || value === undefined || Number.isNaN(value)) {
    return "—";
  }
  return new Intl.NumberFormat(locale === "ar" ? "ar-EG" : "en-GB").format(value);
}

/** Convert a number to Arabic-Indic digits. */
export function toArabicDigits(value: number | string): string {
  const map = ["٠", "١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩"];
  return String(value).replace(/\d/g, (d) => map[Number(d)]!);
}

/** Today's date as YYYY-MM-DD (for inputs / API day params). Local, not UTC. */
export function todayISO(): string {
  const d = new Date();
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

/** Current month as YYYY-MM (for payroll/period params). Local, not UTC. */
export function currentMonth(): string {
  const d = new Date();
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, "0");
  return `${year}-${month}`;
}
