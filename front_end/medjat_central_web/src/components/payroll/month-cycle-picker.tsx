"use client";

import { Button } from "@/components/ui/button";
import { useT } from "@/lib/i18n/use-t";
import type { TKey } from "@/lib/i18n/ar";
import {
  cycleWindowFrom,
  cycleWindowTo,
  cycleLabelContaining,
  isBefore,
  type LabelMonth,
} from "@/lib/payroll-cycle";
import { ChevronRight, ChevronLeft, CalendarDays } from "lucide-react";

interface Props {
  month: number;
  year: number;
  cycleStartDay: number;
  minHireDate: Date | null;
  onChange: (month: number, year: number) => void;
}

/**
 * Month picker by name with ‹ › arrows and the cycle's date-range hint —
 * mirrors the mobile app's _MonthPicker. Capped at the earliest reachable
 * cycle (first hire) and the current cycle (no future months).
 */
export function MonthCyclePicker({
  month,
  year,
  cycleStartDay,
  minHireDate,
  onChange,
}: Props) {
  const { t, locale } = useT();
  const lm: LabelMonth = { year, month };

  const minReach = minHireDate
    ? cycleLabelContaining(minHireDate, cycleStartDay)
    : null;
  const maxLabel = cycleLabelContaining(new Date(), cycleStartDay);

  const lte = (a: LabelMonth, b: LabelMonth) =>
    !isBefore(b, a); // a <= b
  const gte = (a: LabelMonth, b: LabelMonth) =>
    !isBefore(a, b); // a >= b

  const prevDisabled = minReach ? lte(lm, minReach) : false;
  const nextDisabled = gte(lm, maxLabel);

  const step = (delta: number) => {
    const d = new Date(year, month - 1 + delta, 1);
    onChange(d.getMonth() + 1, d.getFullYear());
  };

  const from = cycleWindowFrom(lm, cycleStartDay);
  const to = cycleWindowTo(lm, cycleStartDay);
  const dateFmt = new Intl.DateTimeFormat(
    locale === "ar" ? "ar-EG" : "en-GB",
    { day: "numeric", month: "short" },
  );
  const rangeHint = `${dateFmt.format(from)} – ${dateFmt.format(to)}`;
  const label = `${t(`month_${month}` as TKey)} ${year}`;

  // "Back in time" points right in RTL, left in LTR.
  const isRtl = locale === "ar";
  const BackIcon = isRtl ? ChevronRight : ChevronLeft;
  const FwdIcon = isRtl ? ChevronLeft : ChevronRight;

  return (
    <div className="flex items-center justify-center gap-2">
      <Button
        variant="ghost"
        size="sm"
        aria-label={t("previous")}
        disabled={prevDisabled}
        onClick={() => step(-1)}
      >
        <BackIcon className="h-5 w-5" />
      </Button>

      <div className="flex min-w-44 flex-col items-center">
        <span className="flex items-center gap-1.5 text-body-lg font-semibold">
          <CalendarDays className="h-4 w-4 text-muted-foreground" />
          {label}
        </span>
        <span className="text-xs text-muted-foreground">{rangeHint}</span>
      </div>

      <Button
        variant="ghost"
        size="sm"
        aria-label={t("next")}
        disabled={nextDisabled}
        onClick={() => step(1)}
      >
        <FwdIcon className="h-5 w-5" />
      </Button>
    </div>
  );
}
