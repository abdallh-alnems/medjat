"use client";

import { useState } from "react";
import { useT } from "@/lib/i18n/use-t";
import {
  useOvertimeLateReport,
  useOvertimeLateDays,
} from "@/lib/hooks/use-reports";
import { useBranches } from "@/lib/hooks/use-org";
import { ReportPeriodSelector } from "@/components/report/report-period-selector";
import { ReportExport } from "@/components/report/report-export";
import { LoadingState, ErrorState, EmptyState } from "@/components/ui/states";
import { Card, CardContent } from "@/components/ui/card";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { todayISO } from "@/lib/utils";
import { TrendingUp, Clock, Timer } from "lucide-react";
import type { OvertimeLateRow } from "@/lib/types";

type SortKey = "overtime" | "late" | "name";

/** Formats a minute count as "2h 30min" / "45min" using the short unit labels. */
function useMinuteFormatter() {
  const { t } = useT();
  return (minutes: number) => {
    if (!minutes || minutes <= 0) return `0${t("minutes_short")}`;
    const h = Math.floor(minutes / 60);
    const m = minutes % 60;
    if (h === 0) return `${m}${t("minutes_short")}`;
    if (m === 0) return `${h}${t("hours_short")}`;
    return `${h}${t("hours_short")} ${m}${t("minutes_short")}`;
  };
}

export default function OvertimeLateReportPage() {
  const { t } = useT();
  const fmt = useMinuteFormatter();
  const { data: branches } = useBranches();

  const [from, setFrom] = useState(todayISO().slice(0, 8) + "01");
  const [to, setTo] = useState(todayISO());
  const [branchId, setBranchId] = useState<number | undefined>(undefined);
  const [sort, setSort] = useState<SortKey>("overtime");
  const [openRow, setOpenRow] = useState<OvertimeLateRow | null>(null);

  const params = { from, to, branch_id: branchId, sort };
  const { data, isLoading, isError, refetch } = useOvertimeLateReport(params);

  const rows = data?.items ?? [];
  const summary = data?.summary;

  // Reuses the shared export widget, so PDF/Excel/CSV/Word all come for free.
  const report = {
    title: t("overtime_late_report"),
    period: `${from} – ${to}`,
    columns: [
      t("employee"),
      t("branch"),
      t("total_overtime"),
      t("overtime_days"),
      t("total_late_minutes"),
      t("late_days"),
      t("worst_late"),
    ],
    rows: rows.map((r) => [
      r.employee_name,
      r.branch_name ?? "—",
      fmt(r.overtime_minutes),
      r.overtime_days,
      fmt(r.late_minutes),
      r.late_days,
      fmt(r.worst_late_minutes),
    ]),
  };

  return (
    <div className="space-y-4">
      <h1 className="text-headline-md font-bold">{t("overtime_late_report")}</h1>

      <div className="flex flex-wrap items-end gap-3">
        <ReportPeriodSelector
          from={from}
          to={to}
          onFromChange={setFrom}
          onToChange={setTo}
        />

        <div className="space-y-1.5">
          <Label>{t("branch")}</Label>
          <Select
            value={branchId ? String(branchId) : "all"}
            onValueChange={(v) =>
              setBranchId(!v || v === "all" ? undefined : Number(v))
            }
          >
            <SelectTrigger className="w-44">
              <SelectValue>
                {(v) =>
                  !v || v === "all"
                    ? t("all_branches")
                    : ((branches ?? []).find((b) => String(b.id) === v)?.name ??
                      String(v))
                }
              </SelectValue>
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">{t("all_branches")}</SelectItem>
              {(branches ?? []).map((b) => (
                <SelectItem key={b.id} value={String(b.id)}>
                  {b.name}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>

        <div className="space-y-1.5">
          <Label>{t("sort_by")}</Label>
          <Select
            value={sort}
            onValueChange={(v) => setSort((v ?? "overtime") as SortKey)}
          >
            <SelectTrigger className="w-40">
              <SelectValue>
                {(v) =>
                  v === "late"
                    ? t("sort_most_late")
                    : v === "name"
                      ? t("sort_name")
                      : t("sort_most_overtime")
                }
              </SelectValue>
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="overtime">{t("sort_most_overtime")}</SelectItem>
              <SelectItem value="late">{t("sort_most_late")}</SelectItem>
              <SelectItem value="name">{t("sort_name")}</SelectItem>
            </SelectContent>
          </Select>
        </div>

        {rows.length > 0 && (
          <div className="ms-auto">
            <ReportExport report={report} />
          </div>
        )}
      </div>

      {isLoading ? (
        <LoadingState />
      ) : isError ? (
        <ErrorState onRetry={() => refetch()} />
      ) : (
        <>
          <div className="grid gap-3 sm:grid-cols-2">
            <SummaryCard
              icon={TrendingUp}
              label={t("total_overtime")}
              value={fmt(summary?.total_overtime_minutes ?? 0)}
              caption={`${summary?.overtime_days ?? 0} ${t("days")} • ${
                summary?.employees_with_overtime ?? 0
              } ${t("employee")}`}
              tone="success"
            />
            <SummaryCard
              icon={Clock}
              label={t("total_late_minutes")}
              value={fmt(summary?.total_late_minutes ?? 0)}
              caption={`${summary?.late_days ?? 0} ${t("days")} • ${
                summary?.employees_late ?? 0
              } ${t("employee")}`}
              tone="warning"
            />
          </div>

          {rows.length === 0 ? (
            <EmptyState message={t("no_overtime_late_data")} icon={Timer} />
          ) : (
            <div className="overflow-x-auto rounded-lg border">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>{t("employee")}</TableHead>
                    <TableHead>{t("branch")}</TableHead>
                    <TableHead>{t("total_overtime")}</TableHead>
                    <TableHead>{t("overtime_days")}</TableHead>
                    <TableHead>{t("total_late_minutes")}</TableHead>
                    <TableHead>{t("late_days")}</TableHead>
                    <TableHead>{t("avg_late_minutes")}</TableHead>
                    <TableHead>{t("worst_late")}</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {rows.map((r) => (
                    <TableRow
                      key={r.employee_id}
                      onClick={() => setOpenRow(r)}
                      className="cursor-pointer"
                    >
                      <TableCell className="font-medium">
                        {r.employee_name}
                        {r.job_title && (
                          <span className="block text-xs text-muted-foreground">
                            {r.job_title}
                          </span>
                        )}
                      </TableCell>
                      <TableCell>{r.branch_name ?? "—"}</TableCell>
                      <TableCell className="text-success">
                        {r.overtime_minutes > 0 ? fmt(r.overtime_minutes) : "—"}
                      </TableCell>
                      <TableCell>{r.overtime_days}</TableCell>
                      <TableCell className="text-warning">
                        {r.late_minutes > 0 ? fmt(r.late_minutes) : "—"}
                      </TableCell>
                      <TableCell>{r.late_days}</TableCell>
                      <TableCell>
                        {r.late_days > 0
                          ? fmt(Math.floor(r.late_minutes / r.late_days))
                          : "—"}
                      </TableCell>
                      <TableCell>
                        {r.worst_late_minutes > 0
                          ? fmt(r.worst_late_minutes)
                          : "—"}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          )}
        </>
      )}

      <DaysSheet
        row={openRow}
        onClose={() => setOpenRow(null)}
        params={{ from, to }}
      />
    </div>
  );
}

function SummaryCard({
  icon: Icon,
  label,
  value,
  caption,
  tone,
}: {
  icon: React.ElementType;
  label: string;
  value: string;
  caption: string;
  tone: "success" | "warning";
}) {
  return (
    <Card>
      <CardContent className="p-4">
        <div className="flex items-center gap-2 text-xs text-muted-foreground">
          <Icon
            className={
              "h-4 w-4 " + (tone === "success" ? "text-success" : "text-warning")
            }
          />
          {label}
        </div>
        <p
          className={
            "mt-1 text-headline-md font-bold " +
            (tone === "success" ? "text-success" : "text-warning")
          }
        >
          {value}
        </p>
        <p className="text-xs text-muted-foreground">{caption}</p>
      </CardContent>
    </Card>
  );
}

/** Day-by-day breakdown behind one employee's totals. */
function DaysSheet({
  row,
  onClose,
  params,
}: {
  row: OvertimeLateRow | null;
  onClose: () => void;
  params: { from: string; to: string };
}) {
  const { t } = useT();
  const fmt = useMinuteFormatter();
  const { data, isLoading, isError, refetch } = useOvertimeLateDays({
    ...params,
    employee_id: row?.employee_id,
  });

  const days = data?.days ?? [];
  const time = (v?: string | null) => (v ? v.slice(0, 5) : "—");

  return (
    <Sheet open={!!row} onOpenChange={(open) => !open && onClose()}>
      <SheetContent side="left" className="w-full max-w-md space-y-4">
        <SheetHeader>
          <SheetTitle>{row?.employee_name ?? ""}</SheetTitle>
        </SheetHeader>

        {isLoading ? (
          <LoadingState />
        ) : isError ? (
          <ErrorState onRetry={() => refetch()} />
        ) : days.length === 0 ? (
          <EmptyState message={t("no_report_data")} />
        ) : (
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>{t("date")}</TableHead>
                <TableHead>{t("check_in")}</TableHead>
                <TableHead>{t("check_out")}</TableHead>
                <TableHead>{t("overtime_by")}</TableHead>
                <TableHead>{t("late_by")}</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {days.map((d) => (
                <TableRow key={d.date}>
                  <TableCell className="font-medium">{d.date}</TableCell>
                  <TableCell>{time(d.check_in_time)}</TableCell>
                  <TableCell>{time(d.check_out_time)}</TableCell>
                  <TableCell className="text-success">
                    {d.overtime_minutes > 0 ? fmt(d.overtime_minutes) : "—"}
                  </TableCell>
                  <TableCell className="text-warning">
                    {d.late_minutes > 0 ? fmt(d.late_minutes) : "—"}
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        )}
      </SheetContent>
    </Sheet>
  );
}
