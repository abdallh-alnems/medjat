"use client";

import { useT } from "@/lib/i18n/use-t";
import { useUIStore } from "@/lib/stores/ui-store";
import { formatEGP } from "@/lib/utils";
import type { DashboardPayrollSummary } from "@/lib/types";
import { Wallet, TrendingUp, TrendingDown, Coins } from "lucide-react";

export function PayrollSummary({ data }: { data: DashboardPayrollSummary }) {
  const { t } = useT();
  const locale = useUIStore((s) => s.locale);
  const rows: { label: string; value: number; icon: React.ElementType; tone: string }[] = [
    {
      label: t("net_pay"),
      value: data.net,
      icon: Wallet,
      tone: "text-brand",
    },
    {
      label: t("base_salary"),
      value: data.base,
      icon: Coins,
      tone: "text-muted-foreground",
    },
    {
      label: t("bonuses"),
      value: data.bonuses,
      icon: TrendingUp,
      tone: "text-success",
    },
    {
      label: t("deductions"),
      value: data.deductions,
      icon: TrendingDown,
      tone: "text-destructive",
    },
  ];
  return (
    <div className="card-flat">
      <h3 className="mb-3 text-title-lg font-semibold">{t("payroll_summary")}</h3>
      <div className="grid grid-cols-2 gap-3">
        {rows.map((r) => {
          const Icon = r.icon;
          return (
            <div key={r.label} className="flex items-center gap-2">
              <Icon className={`h-4 w-4 ${r.tone}`} />
              <div>
                <p className="text-label-sm text-muted-foreground">{r.label}</p>
                <p className="text-title-md font-semibold">
                  {formatEGP(r.value, locale)}
                </p>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

export function AttendanceSummary({
  rate,
  present,
  total,
}: {
  rate: number;
  present: number;
  total: number;
}) {
  const { t } = useT();
  const pct = Math.round(rate * 100);
  return (
    <div className="card-flat flex items-center justify-between">
      <div>
        <p className="text-label-md text-muted-foreground">
          {t("attendance_rate")}
        </p>
        <p className="text-display-sm font-bold text-brand">{pct}%</p>
        <p className="text-label-sm text-muted-foreground">
          {present} / {total}
        </p>
      </div>
      <div className="h-16 w-16">
        <svg viewBox="0 0 36 36" className="h-full w-full">
          <circle
            cx="18"
            cy="18"
            r="15.5"
            fill="none"
            stroke="currentColor"
            strokeWidth="3.5"
            className="text-muted/40"
          />
          <circle
            cx="18"
            cy="18"
            r="15.5"
            fill="none"
            stroke="currentColor"
            strokeWidth="3.5"
            strokeDasharray={`${pct}, 100`}
            strokeLinecap="round"
            className="text-brand -rotate-90 [transform-origin:center]"
          />
        </svg>
      </div>
    </div>
  );
}
