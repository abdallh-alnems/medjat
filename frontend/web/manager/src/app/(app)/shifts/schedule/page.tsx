"use client";

import { useState } from "react";
import { useT } from "@/lib/i18n/use-t";
import { useShifts } from "@/lib/hooks/use-org";
import {
  getWeeklySchedule,
  assignSchedule,
  clearSchedule,
  copyWeek,
  publishSchedule,
} from "@/lib/api/branches";
import { useToastMutation } from "@/lib/hooks/use-org";
import {
  LoadingState,
  ErrorState,
} from "@/components/ui/states";
import { Button } from "@/components/ui/button";
import { useQuery } from "@tanstack/react-query";
import { todayISO } from "@/lib/utils";
import type { TKey } from "@/lib/i18n/ar";

const DAY_KEYS: TKey[] = [
  "sunday",
  "monday",
  "tuesday",
  "wednesday",
  "thursday",
  "friday",
  "saturday",
];

export default function SchedulePage() {
  const { t } = useT();
  const { data: shifts } = useShifts();
  const [week, setWeek] = useState(todayISO());

  const schedule = useQuery({
    queryKey: ["org", "schedule", week],
    queryFn: () => getWeeklySchedule(week),
  });

  const assign = useToastMutation(
    (args: { employee_id: number; shift_id: number; day: number }) =>
      assignSchedule(args),
    { invalidate: [["org", "schedule", week] as const] },
  );
  const clear = useToastMutation(
    (args: { employee_id: number; shift_id: number; day: number }) =>
      clearSchedule(args),
    { invalidate: [["org", "schedule", week] as const] },
  );
  const copy = useToastMutation(
    (toWeek: string) => copyWeek(week, toWeek),
    { successMessage: t("success") },
  );
  const publish = useToastMutation(
    () => publishSchedule(week),
    {
      successMessage: t("success"),
      invalidate: [["org", "schedule", week] as const],
    },
  );

  const assignments = schedule.data?.assignments ?? [];
  const [empId, setEmpId] = useState("");
  const [shiftId, setShiftId] = useState("");
  const [copyTarget, setCopyTarget] = useState("");

  const cellFor = (day: number) =>
    assignments.filter(
      (a) => a.day === day && String(a.shift_id) === String(shiftId),
    );

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between gap-2">
        <h1 className="text-headline-md font-bold">{t("weekly_schedule")}</h1>
        <div className="flex gap-2">
          <Button
            variant="outline"
            size="sm"
            onClick={() => copy.mutate(copyTarget)}
            disabled={copy.isPending || !copyTarget}
          >
            {t("copy_week")}
          </Button>
          <Button
            size="sm"
            onClick={() => publish.mutate(undefined)}
            disabled={publish.isPending}
          >
            {t("publish_schedule")}
          </Button>
        </div>
      </div>

      <div className="flex items-end gap-3">
        <div className="space-y-1.5">
          <label className="text-xs text-muted-foreground">{t("date")}</label>
          <input
            type="date"
            value={week}
            onChange={(e) => setWeek(e.target.value)}
            className="h-8 rounded-lg border bg-transparent px-2 text-sm"
          />
        </div>
        <div className="space-y-1.5">
          <label className="text-xs text-muted-foreground">{t("employee")}</label>
          <input
            type="number"
            value={empId}
            onChange={(e) => setEmpId(e.target.value)}
            className="h-8 w-24 rounded-lg border bg-transparent px-2 text-sm"
          />
        </div>
        <div className="space-y-1.5">
          <label className="text-xs text-muted-foreground">{t("shift")}</label>
          <select
            value={shiftId}
            onChange={(e) => setShiftId(e.target.value)}
            className="h-8 rounded-lg border bg-transparent px-2 text-sm"
          >
            <option value="">{t("none")}</option>
            {(shifts ?? []).map((s) => (
              <option key={s.id} value={s.id}>
                {s.name}
              </option>
            ))}
          </select>
        </div>
        <div className="space-y-1.5">
          <label className="text-xs text-muted-foreground">{t("copy_to")}</label>
          <input
            type="date"
            value={copyTarget}
            onChange={(e) => setCopyTarget(e.target.value)}
            className="h-8 rounded-lg border bg-transparent px-2 text-sm"
          />
        </div>
      </div>

      {schedule.isLoading ? (
        <LoadingState />
      ) : schedule.isError ? (
        <ErrorState onRetry={() => schedule.refetch()} />
      ) : (
        <div className="grid grid-cols-2 gap-2 sm:grid-cols-4 lg:grid-cols-7">
          {DAY_KEYS.map((dayKey, day) => (
            <div key={dayKey} className="rounded-lg border p-2">
              <p className="mb-2 text-xs font-medium">{t(dayKey)}</p>
              <div className="space-y-1">
                {cellFor(day).length > 0 ? (
                  cellFor(day).map((a, i) => (
                    <div
                      key={i}
                      className="flex items-center justify-between rounded bg-muted px-1 py-0.5 text-xs"
                    >
                      <span>#{a.employee_id}</span>
                      <button
                        className="text-destructive"
                        onClick={() =>
                          clear.mutate({
                            employee_id: a.employee_id,
                            shift_id: Number(shiftId) || a.shift_id,
                            day,
                          })
                        }
                      >
                        ×
                      </button>
                    </div>
                  ))
                ) : (
                  <p className="text-xs text-muted-foreground">{t("none")}</p>
                )}
              </div>
              {empId && shiftId && Number(empId) > 0 && Number(shiftId) > 0 && (
                <Button
                  variant="ghost"
                  size="sm"
                  className="mt-1 h-6 w-full text-xs"
                  onClick={() => {
                    const eid = Number(empId);
                    const sid = Number(shiftId);
                    if (!eid || !sid) return;
                    assign.mutate({
                      employee_id: eid,
                      shift_id: sid,
                      day,
                    });
                  }}
                >
                  {t("add")}
                </Button>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
