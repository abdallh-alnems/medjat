"use client";

import { useState } from "react";
import Link from "next/link";
import { useT } from "@/lib/i18n/use-t";
import { useShifts } from "@/lib/hooks/use-org";
import { useToastMutation } from "@/lib/hooks/use-org";
import { createShift } from "@/lib/api/branches";
import {
  LoadingState,
  ErrorState,
  EmptyState,
} from "@/components/ui/states";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Plus, Clock, Users } from "lucide-react";
import type { Shift } from "@/lib/types";

const DAYS = [
  "sunday",
  "monday",
  "tuesday",
  "wednesday",
  "thursday",
  "friday",
  "saturday",
];

export default function ShiftsPage() {
  const { t } = useT();
  const { data, isLoading, isError, refetch } = useShifts();
  const shifts = Array.isArray(data) ? data : [];

  const [name, setName] = useState("");
  const [start, setStart] = useState("08:00");
  const [end, setEnd] = useState("16:00");
  const [days, setDays] = useState<number[]>([0, 1, 2, 3, 4]);

  const create = useToastMutation(
    (data: Partial<Shift>) =>
      createShift({ name: name || "وردية", start, end, days, ...data }),
    { successMessage: t("success"), invalidate: [["org", "shifts"] as const] },
  );

  const toggleDay = (i: number) =>
    setDays((d) => (d.includes(i) ? d.filter((x) => x !== i) : [...d, i]));

  return (
    <div className="space-y-4">
      <h1 className="text-headline-md font-bold">{t("shifts")}</h1>

      <Card>
        <CardContent className="space-y-3 p-4">
          <div className="grid gap-3 sm:grid-cols-3">
            <div className="space-y-1.5">
              <Label>{t("shift_name")}</Label>
              <Input value={name} onChange={(e) => setName(e.target.value)} />
            </div>
            <div className="space-y-1.5">
              <Label>{t("start_time")}</Label>
              <Input type="time" value={start} onChange={(e) => setStart(e.target.value)} />
            </div>
            <div className="space-y-1.5">
              <Label>{t("end_time")}</Label>
              <Input type="time" value={end} onChange={(e) => setEnd(e.target.value)} />
            </div>
          </div>
          <div className="flex flex-wrap gap-2">
            {DAYS.map((d, i) => (
              <label
                key={d}
                className={
                  "cursor-pointer rounded-lg border px-3 py-1 text-xs " +
                  (days.includes(i)
                    ? "border-primary bg-primary text-primary-foreground"
                    : "text-muted-foreground")
                }
              >
                <input
                  type="checkbox"
                  className="sr-only"
                  checked={days.includes(i)}
                  onChange={() => toggleDay(i)}
                />
                {t(d as never)}
              </label>
            ))}
          </div>
          <Button onClick={() => create.mutate({})} disabled={create.isPending}>
            <Plus className="h-4 w-4" />
            {t("add_shift")}
          </Button>
        </CardContent>
      </Card>

      {isLoading ? (
        <LoadingState />
      ) : isError ? (
        <ErrorState onRetry={() => refetch()} />
      ) : shifts.length === 0 ? (
        <EmptyState message={t("no_data")} icon={Clock} />
      ) : (
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {shifts.map((s) => (
            <Card key={s.id}>
              <CardContent className="space-y-2 p-4">
                <div className="flex items-start justify-between">
                  <div>
                    <p className="font-semibold">{s.name}</p>
                    <p className="text-xs text-muted-foreground">
                      {s.start} — {s.end}
                    </p>
                  </div>
                  {s.members && (
                    <span className="text-xs text-muted-foreground">
                      <Users className="me-1 inline h-3 w-3" />
                      {s.members.length}
                    </span>
                  )}
                </div>
                <Button
                  variant="outline"
                  size="sm"
                  render={<Link href={`/shifts/assign?id=${s.id}`} />}
                >
                  {t("assign_members")}
                </Button>
              </CardContent>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
