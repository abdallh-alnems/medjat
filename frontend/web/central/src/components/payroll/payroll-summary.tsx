"use client";

import { useT } from "@/lib/i18n/use-t";
import {
  ArrowUp,
  ArrowDown,
  TrendingUp,
  TrendingDown,
  CheckCircle2,
  Wallet,
} from "lucide-react";

const CURRENCY_LABEL: Record<string, string> = {
  EGP: "ج.م",
  SAR: "ر.س",
  AED: "د.إ",
  USD: "$",
  KWD: "د.ك",
  QAR: "ر.ق",
};

interface Props {
  net: number;
  base: number;
  bonuses: number;
  deductions: number;
  delta: number | null;
  employeeCount: number;
  paidCount: number;
  scopedCount: number;
  currency: string;
}

/**
 * Branded payroll summary card, mirroring the mobile app's _PayrollSummaryCard:
 * total net (prominent) + delta, additions / deductions mini-stats, and an
 * employee-count / paid footer. No standalone "base salary" figure — same as
 * the app.
 */
export function PayrollSummary({
  net,
  base,
  bonuses,
  deductions,
  delta,
  employeeCount,
  paidCount,
  scopedCount,
  currency,
}: Props) {
  const { t, locale } = useT();
  const fmt = (n: number) =>
    new Intl.NumberFormat(locale === "ar" ? "ar-EG" : "en-GB").format(
      Math.round(n),
    );
  const cur = CURRENCY_LABEL[currency] ?? currency;

  return (
    <div className="rounded-xl bg-gradient-to-br from-primary to-primary/85 p-4 text-primary-foreground shadow-sm">
      <div className="flex items-end justify-between gap-2">
        <div>
          <p className="text-xs opacity-80">{t("payroll_total_net")}</p>
          <p className="text-3xl leading-none font-extrabold">
            {fmt(net)}{" "}
            <span className="text-sm font-medium opacity-80">{cur}</span>
          </p>
        </div>
        {delta !== null && (
          <span className="flex items-center gap-1 rounded-full bg-white/20 px-2 py-1 text-sm font-semibold">
            {delta >= 0 ? (
              <TrendingUp className="h-3.5 w-3.5" />
            ) : (
              <TrendingDown className="h-3.5 w-3.5" />
            )}
            {fmt(Math.abs(delta))}
          </span>
        )}
      </div>

      <div className="mt-3">
        <MiniStat
          icon={<Wallet className="h-4 w-4" />}
          label={t("payroll_total_base")}
          value={fmt(base)}
        />
      </div>

      <div className="mt-3 grid grid-cols-2 gap-3">
        <MiniStat
          icon={<ArrowUp className="h-4 w-4" />}
          label={t("payroll_total_bonuses")}
          value={fmt(bonuses)}
        />
        <MiniStat
          icon={<ArrowDown className="h-4 w-4" />}
          label={t("payroll_total_deductions")}
          value={fmt(deductions)}
        />
      </div>

      <div className="my-3 h-px bg-white/20" />

      <div className="flex items-center justify-between text-sm">
        <span>
          {employeeCount} {t("employees")}
        </span>
        {paidCount > 0 && (
          <span className="flex items-center gap-1 rounded-full bg-white/20 px-2 py-1 font-semibold">
            <CheckCircle2 className="h-3.5 w-3.5" />
            {paidCount}/{scopedCount} {t("paid_count_label")}
          </span>
        )}
      </div>
    </div>
  );
}

function MiniStat({
  icon,
  label,
  value,
}: {
  icon: React.ReactNode;
  label: string;
  value: string;
}) {
  return (
    <div className="rounded-lg bg-white/10 p-2.5">
      <div className="flex items-center gap-1 text-xs opacity-80">
        {icon}
        {label}
      </div>
      <p className="mt-0.5 text-lg font-bold">{value}</p>
    </div>
  );
}
