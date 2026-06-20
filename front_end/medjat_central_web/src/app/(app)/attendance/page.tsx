"use client";

import { useState, useMemo } from "react";
import { useT } from "@/lib/i18n/use-t";
import { usePermissions } from "@/lib/hooks/use-permissions";
import { useBranchAttendance } from "@/lib/hooks/use-attendance";
import { useLiveAttendance } from "@/lib/hooks/use-dashboard";
import { useBranches } from "@/lib/hooks/use-org";
import { Can } from "@/components/permissions/can";
import {
  LoadingState,
  ErrorState,
  EmptyState,
} from "@/components/ui/states";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { AttendanceTable } from "@/components/attendance/attendance-table";
import { LiveBoard } from "@/components/attendance/live-board";
import { ManualRecordSheet } from "@/components/attendance/manual-record-sheet";
import { exportReportToPDF, exportReportToExcel } from "@/lib/export";
import { todayISO } from "@/lib/utils";
import type { AttendanceRecord } from "@/lib/types";
import { Radio, FileDown } from "lucide-react";

type SortKey = "name" | "status" | "check_in";

export default function AttendancePage() {
  const { t, locale } = useT();
  const { can } = usePermissions();
  const { data: branches } = useBranches();

  const [branchId, setBranchId] = useState<number | undefined>(undefined);
  const [date, setDate] = useState(todayISO());
  const [selected, setSelected] = useState<number[]>([]);
  const [sort, setSort] = useState<SortKey>("check_in");
  const [tab, setTab] = useState<"day" | "live">("day");

  const { data, isLoading, isError, refetch } = useBranchAttendance({
    branch_id: branchId,
    date,
  });

  const live = useLiveAttendance(tab === "live");

  const records: AttendanceRecord[] = Array.isArray(data) ? data : [];

  const sorted = useMemo(() => {
    const cmp = (a: AttendanceRecord, b: AttendanceRecord) => {
      if (sort === "status") return a.status.localeCompare(b.status);
      if (sort === "check_in")
        return (a.check_in ?? "z").localeCompare(b.check_in ?? "z");
      return a.employee_id - b.employee_id;
    };
    return [...records].sort(cmp);
  }, [records, sort]);

  const toggle = (id: number) =>
    setSelected((s) => (s.includes(id) ? s.filter((x) => x !== id) : [...s, id]));

  const toggleAll = (ids: number[]) =>
    setSelected((s) =>
      ids.every((id) => s.includes(id)) ? [] : ids,
    );

  const exportRows = (fmt: "pdf" | "excel") => {
    if (sorted.length === 0) return;
    const report = {
      title: `${t("attendance")} — ${date}`,
      period: date,
      columns: [
        t("employee"),
        t("status"),
        t("check_in_time"),
        t("check_out_time"),
        t("late_minutes"),
      ],
      rows: sorted.map((r) => [
        r.employee_id,
        t(r.status),
        r.check_in ?? "",
        r.check_out ?? "",
        r.late_minutes,
      ]),
    };
    if (fmt === "pdf") exportReportToPDF(report, { locale });
    else exportReportToExcel(report);
  };

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between gap-2">
        <h1 className="text-headline-md font-bold">{t("attendance")}</h1>
        <Can permission="manage_attendance">
          <ManualRecordSheet
            date={date}
            employeeIds={selected}
            onDone={() => setSelected([])}
          />
        </Can>
      </div>

      <div className="inline-flex rounded-lg border p-1">
        {(["day", "live"] as const).map((k) => (
          <button
            key={k}
            onClick={() => setTab(k)}
            className={
              "rounded-md px-4 py-1.5 text-body-md transition-colors " +
              (tab === k
                ? "bg-primary text-primary-foreground font-medium"
                : "text-muted-foreground hover:text-foreground")
            }
          >
            {k === "day" ? t("date") : t("live_board")}
          </button>
        ))}
      </div>

      {tab === "day" ? (
        <>
          <div className="flex flex-wrap items-end gap-3">
            <div className="space-y-1.5">
              <Label>{t("branch")}</Label>
              <Select
                value={branchId ? String(branchId) : "all"}
                onValueChange={(v) =>
                  setBranchId(!v || v === "all" ? undefined : Number(v))
                }
              >
                <SelectTrigger className="w-48">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">{t("all")}</SelectItem>
                  {(branches ?? []).map((b) => (
                    <SelectItem key={b.id} value={String(b.id)}>
                      {b.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-1.5">
              <Label>{t("date")}</Label>
              <Input
                type="date"
                value={date}
                onChange={(e) => setDate(e.target.value)}
                className="w-44"
              />
            </div>

            <div className="space-y-1.5">
              <Label>{t("sort")}</Label>
              <Select value={sort} onValueChange={(v) => setSort((v ?? "check_in") as SortKey)}>
                <SelectTrigger className="w-40">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="name">{t("sort_name")}</SelectItem>
                  <SelectItem value="status">{t("sort_status")}</SelectItem>
                  <SelectItem value="check_in">{t("sort_check_in")}</SelectItem>
                </SelectContent>
              </Select>
            </div>

            {sorted.length > 0 && (
              <div className="ms-auto flex gap-2">
                <Button variant="outline" size="sm" onClick={() => exportRows("excel")}>
                  <FileDown className="h-4 w-4" />
                  {t("excel")}
                </Button>
                <Button variant="outline" size="sm" onClick={() => exportRows("pdf")}>
                  <FileDown className="h-4 w-4" />
                  {t("pdf")}
                </Button>
              </div>
            )}
          </div>

          {can("manage_attendance") ? (
            isLoading ? (
              <LoadingState />
            ) : isError ? (
              <ErrorState onRetry={() => refetch()} />
            ) : sorted.length === 0 ? (
              <EmptyState message={t("no_records")} icon={Radio} />
            ) : (
              <AttendanceTable
                records={sorted}
                selected={selected}
                onToggleSelect={toggle}
                onToggleAll={toggleAll}
              />
            )
          ) : (
            <EmptyState message={t("permission_denied")} />
          )}
        </>
      ) : (
        <>
          {live.isLoading ? (
            <LoadingState />
          ) : live.isError ? (
            <ErrorState onRetry={() => live.refetch()} />
          ) : (live.data ?? []).length === 0 ? (
            <EmptyState message={t("no_records")} icon={Radio} />
          ) : (
            <LiveBoard rows={live.data ?? []} />
          )}
        </>
      )}
    </div>
  );
}
