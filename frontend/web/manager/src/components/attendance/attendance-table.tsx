"use client";

import { useState, useMemo } from "react";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { Checkbox } from "@/components/ui/checkbox";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { useT } from "@/lib/i18n/use-t";
import { useSetDayStatus } from "@/lib/hooks/use-attendance";
import { useToastMutation } from "@/lib/hooks/use-org";
import { NoteDialog } from "./note-dialog";
import { PunchPhotoButton } from "./punch-photo-dialog";
import type { AttendanceRecord, AttendanceStatus } from "@/lib/types";
import type { TKey } from "@/lib/i18n/ar";
import { ATTENDANCE_STATUS_TONE } from "@/lib/constants/attendance";

const STATUSES: AttendanceStatus[] = [
  "present",
  "absent",
  "late",
  "leave",
  "holiday",
];

interface Props {
  records: AttendanceRecord[];
  selected: number[];
  onToggleSelect: (id: number) => void;
  onToggleAll: (ids: number[]) => void;
}

export function AttendanceTable({
  records,
  selected,
  onToggleSelect,
  onToggleAll,
}: Props) {
  const { t, locale } = useT();
  const setDayStatus = useSetDayStatus();

  const selectedSet = useMemo(() => new Set(selected), [selected]);
  const allSelected =
    records.length > 0 && records.every((r) => selectedSet.has(r.id));

  const mutate = useToastMutation(
    async (args: { record: AttendanceRecord; status: AttendanceStatus }) =>
      setDayStatus.mutateAsync({
        employeeId: args.record.employee_id,
        date: args.record.date,
        status: args.status,
      }),
    { successMessage: t("success") },
  );

  const sorted = useMemo(
    () => [...records].sort((a, b) => (a.check_in ?? "z").localeCompare(b.check_in ?? "z")),
    [records],
  );

  return (
    <div className="rounded-lg border">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead className="w-8">
              <Checkbox
                checked={allSelected}
                onCheckedChange={() =>
                  onToggleAll(records.map((r) => r.id))
                }
                aria-label={t("all")}
              />
            </TableHead>
            <TableHead>{t("name")}</TableHead>
            <TableHead>{t("status")}</TableHead>
            <TableHead>{t("check_in_time")}</TableHead>
            <TableHead>{t("check_out_time")}</TableHead>
            <TableHead>{t("late_minutes")}</TableHead>
            <TableHead>{t("set_day_status")}</TableHead>
            <TableHead>{t("note")}</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {sorted.map((r) => (
            <TableRow key={r.id}>
              <TableCell>
                <Checkbox
                  checked={selected.includes(r.id)}
                  onCheckedChange={() => onToggleSelect(r.id)}
                  aria-label={`${t("name")} ${r.employee_id}`}
                />
              </TableCell>
              <TableCell className="font-medium">
                <span className="flex flex-wrap items-center gap-1">
                  {r.employee_name ?? `${t("employee")} #${r.employee_id}`}
                  {/* Advisory only — one browser, two employees. It is shown so a
                      human can ask, never as a rejection (spec FR-020). */}
                  {r.shared_device_flag && (
                    <Badge variant="secondary" title={t("shared_device_hint")}>
                      {t("shared_device")}
                    </Badge>
                  )}
                </span>
              </TableCell>
              <TableCell>
                <Badge variant={ATTENDANCE_STATUS_TONE[r.status]}>{t(r.status)}</Badge>
              </TableCell>
              <TableCell>
                <span className="flex items-center gap-1">
                  {r.check_in ?? "—"}
                  {r.check_in_origin === "web" && (
                    <Badge variant="outline" title={t("punch_photo_web")}>
                      {t("punch_photo_web")}
                    </Badge>
                  )}
                  {r.has_check_in_photo && (
                    <PunchPhotoButton
                      attendanceId={r.id}
                      which="check_in"
                      label={t("check_in_time")}
                    />
                  )}
                </span>
              </TableCell>
              <TableCell>
                <span className="flex items-center gap-1">
                  {r.check_out ?? "—"}
                  {r.has_check_out_photo && (
                    <PunchPhotoButton
                      attendanceId={r.id}
                      which="check_out"
                      label={t("check_out_time")}
                    />
                  )}
                </span>
              </TableCell>
              <TableCell>
                {r.late_minutes ? new Intl.NumberFormat(locale === "ar" ? "ar-EG" : "en-GB").format(r.late_minutes) : "—"}
              </TableCell>
              <TableCell>
                <Select
                  value={r.status}
                  onValueChange={(v) =>
                    mutate.mutate({ record: r, status: v as AttendanceStatus })
                  }
                >
                  <SelectTrigger className="h-8 w-32">
                    <SelectValue>{(v) => t(v as TKey)}</SelectValue>
                  </SelectTrigger>
                  <SelectContent>
                    {STATUSES.map((s) => (
                      <SelectItem key={s} value={s}>
                        {t(s)}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </TableCell>
              <TableCell>
                <NoteDialog record={r} />
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  );
}
