"use client";

import Link from "next/link";
import { useT } from "@/lib/i18n/use-t";
import { useUIStore } from "@/lib/stores/ui-store";
import { formatNumber, cn } from "@/lib/utils";
import { Building2 } from "lucide-react";
import type { BranchPerformance } from "@/lib/types";

/** Per-branch attendance tiles (mirrors the mobile app's "branch performance"). */
export function BranchPerformanceList({
  branches,
}: {
  branches: BranchPerformance[];
}) {
  const { t } = useT();
  const locale = useUIStore((s) => s.locale);

  return (
    <div className="space-y-3">
      {branches.map((b) => {
        const rate = Math.round(b.rate);
        const rateTone =
          rate >= 80
            ? "text-success"
            : rate >= 50
              ? "text-warning"
              : "text-destructive";
        return (
          <Link
            key={b.branch_id}
            href="/branches"
            className="card-flat block transition-shadow hover:shadow-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand"
          >
            <div className="flex items-center justify-between gap-3">
              <div className="flex min-w-0 items-center gap-2">
                <Building2 className="h-4 w-4 shrink-0 text-brand" />
                <p className="truncate text-title-md font-semibold">
                  {b.branch_name}
                </p>
              </div>
              <p className={cn("text-title-lg font-bold", rateTone)}>{rate}%</p>
            </div>

            {/* progress bar */}
            <div className="mt-2 h-2 w-full overflow-hidden rounded-full bg-muted">
              <div
                className={cn(
                  "h-full rounded-full",
                  rate >= 80
                    ? "bg-success"
                    : rate >= 50
                      ? "bg-warning"
                      : "bg-destructive",
                )}
                style={{ width: `${Math.min(100, Math.max(0, rate))}%` }}
              />
            </div>

            <div className="mt-3 flex flex-wrap gap-x-4 gap-y-1 text-label-sm text-muted-foreground">
              <span>
                {t("present")}:{" "}
                <b className="text-foreground">
                  {formatNumber(b.present, locale)}/{formatNumber(b.total, locale)}
                </b>
              </span>
              <span>
                {t("absent")}:{" "}
                <b className="text-foreground">{formatNumber(b.absent, locale)}</b>
              </span>
              <span>
                {t("late")}:{" "}
                <b className="text-foreground">{formatNumber(b.late, locale)}</b>
              </span>
              {b.late_rate >= 0 && (
                <span>
                  {t("late_rate")}:{" "}
                  <b className="text-foreground">{Math.round(b.late_rate)}%</b>
                </span>
              )}
            </div>
          </Link>
        );
      })}
    </div>
  );
}
