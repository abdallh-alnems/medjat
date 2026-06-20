"use client";

import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Label } from "@/components/ui/label";
import { useT } from "@/lib/i18n/use-t";

const MONTHS = Array.from({ length: 12 }, (_, i) => i + 1);

/** Period picker: month + year, defaults to current month. */
export function PeriodSelector({
  month,
  year,
  onMonthChange,
  onYearChange,
}: {
  month: number;
  year: number;
  onMonthChange: (m: number) => void;
  onYearChange: (y: number) => void;
}) {
  const { t } = useT();
  const thisYear = new Date().getFullYear();
  const years = [thisYear - 1, thisYear, thisYear + 1];
  return (
    <div className="flex items-end gap-3">
      <div className="space-y-1.5">
        <Label>{t("month")}</Label>
        <Select
          value={String(month)}
          onValueChange={(v) => onMonthChange(Number(v ?? 1))}
        >
          <SelectTrigger className="w-28">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {MONTHS.map((m) => (
              <SelectItem key={m} value={String(m)}>
                {m}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>
      <div className="space-y-1.5">
        <Label>{t("year")}</Label>
        <Select
          value={String(year)}
          onValueChange={(v) => onYearChange(Number(v ?? thisYear))}
        >
          <SelectTrigger className="w-28">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {years.map((y) => (
              <SelectItem key={y} value={String(y)}>
                {y}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>
    </div>
  );
}
