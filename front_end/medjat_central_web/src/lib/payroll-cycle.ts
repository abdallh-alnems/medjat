/**
 * Payroll cycle math, mirroring the mobile app's PayrollController so the web
 * payroll page resolves the same windows, default month, and labels.
 *
 * A "label month" is `{ year, month }` with `month` 1–12. A cycle is named after
 * whichever calendar month holds most of its days (driven by `cycleStartDay`):
 *   D <= 1     → plain calendar month
 *   D in 2..16 → starts in the label month, ends in the next month
 *   D in 17..28→ starts in the prior month, ends in the label month
 */
export interface LabelMonth {
  year: number;
  month: number; // 1–12
}

export function clampCycleStartDay(d: number): number {
  return Math.max(1, Math.min(28, Math.trunc(d)));
}

function labeledByEndMonth(d: number): boolean {
  return d >= 17;
}

/** First calendar day (inclusive) of the cycle whose label month is `lm`. */
export function cycleWindowFrom(lm: LabelMonth, d: number): Date {
  if (d <= 1) return new Date(lm.year, lm.month - 1, 1);
  const offset = labeledByEndMonth(d) ? -1 : 0;
  return new Date(lm.year, lm.month - 1 + offset, d);
}

/** Last calendar day (inclusive) of the cycle whose label month is `lm`. */
export function cycleWindowTo(lm: LabelMonth, d: number): Date {
  if (d <= 1) return new Date(lm.year, lm.month, 0); // last day of label month
  const offset = labeledByEndMonth(d) ? 0 : 1;
  return new Date(lm.year, lm.month - 1 + offset, d - 1);
}

/** Label month of the cycle that contains `date`. */
export function cycleLabelContaining(date: Date, d: number): LabelMonth {
  if (d <= 1) return { year: date.getFullYear(), month: date.getMonth() + 1 };
  const startMonthOffset = date.getDate() >= d ? 0 : -1;
  const labelOffset = labeledByEndMonth(d) ? 1 : 0;
  // Normalise overflow via Date arithmetic.
  const anchor = new Date(date.getFullYear(), date.getMonth() + startMonthOffset + labelOffset, 1);
  return { year: anchor.getFullYear(), month: anchor.getMonth() + 1 };
}

function dayOnly(date: Date): Date {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

/**
 * Label month the picker should default to: the latest cycle whose last day has
 * already passed (companies pay the month that just ended, not the still-open
 * current cycle). Clamped to the earliest reachable month (first hire's cycle).
 */
export function defaultLabelMonth(
  now: Date,
  cycleStartDay: number,
  minHireDate: Date | null,
): LabelMonth {
  const d = clampCycleStartDay(cycleStartDay);
  const current = cycleLabelContaining(now, d);
  const end = cycleWindowTo(current, d);
  // Still inside the current cycle → step back to the completed predecessor.
  let target: LabelMonth;
  if (dayOnly(now) < dayOnly(end)) {
    const prev = new Date(current.year, current.month - 2, 1);
    target = { year: prev.getFullYear(), month: prev.getMonth() + 1 };
  } else {
    target = current;
  }
  if (minHireDate) {
    const floor = cycleLabelContaining(minHireDate, d);
    if (isBefore(target, floor)) return floor;
  }
  return target;
}

export function isBefore(a: LabelMonth, b: LabelMonth): boolean {
  return a.year < b.year || (a.year === b.year && a.month < b.month);
}

/** The label month immediately before `lm`. */
export function previousLabelMonth(lm: LabelMonth): LabelMonth {
  const prev = new Date(lm.year, lm.month - 2, 1);
  return { year: prev.getFullYear(), month: prev.getMonth() + 1 };
}

/** True when `lm`'s cycle hasn't ended yet (today is before its last day). */
export function isCycleOpen(lm: LabelMonth, cycleStartDay: number, now = new Date()): boolean {
  const end = cycleWindowTo(lm, clampCycleStartDay(cycleStartDay));
  return dayOnly(now) < dayOnly(end);
}

export function toPeriod(lm: LabelMonth): string {
  return `${lm.year}-${String(lm.month).padStart(2, "0")}`;
}
