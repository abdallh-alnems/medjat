"use client";

import { useState } from "react";
import Link from "next/link";
import { useT } from "@/lib/i18n/use-t";
import { useShifts, useBranches } from "@/lib/hooks/use-org";
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
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Plus, Clock, Users } from "lucide-react";

export default function ShiftsPage() {
  const { t } = useT();
  const { data, isLoading, isError, refetch } = useShifts();
  const { data: branches } = useBranches();
  const shifts = Array.isArray(data) ? data : [];

  const [name, setName] = useState("");
  const [start, setStart] = useState("08:00");
  const [end, setEnd] = useState("16:00");
  const [branchId, setBranchId] = useState<string>("");

  const create = useToastMutation(
    () =>
      createShift({
        name: name || t("shift"),
        start_time: start,
        end_time: end,
        branch_id: branchId ? Number(branchId) : null,
      }),
    {
      successMessage: t("success"),
      invalidate: [["org", "shifts"] as const],
      onSuccess: () => setName(""),
    },
  );

  return (
    <div className="space-y-4">
      <h1 className="text-headline-md font-bold">{t("shifts")}</h1>

      <Card>
        <CardContent className="space-y-3 p-4">
          <div className="grid gap-3 sm:grid-cols-2">
            <div className="space-y-1.5">
              <Label>{t("shift_name")}</Label>
              <Input value={name} onChange={(e) => setName(e.target.value)} />
            </div>
            <div className="space-y-1.5">
              <Label>{t("branch")}</Label>
              <Select
                value={branchId}
                onValueChange={(v) => setBranchId(v ?? "")}
              >
                <SelectTrigger className="w-full">
                  <SelectValue placeholder={t("all_branches")}>
                    {(v) =>
                      (branches ?? []).find((b) => String(b.id) === v)?.name ??
                      t("all_branches")
                    }
                  </SelectValue>
                </SelectTrigger>
                <SelectContent>
                  {(branches ?? []).map((b) => (
                    <SelectItem key={b.id} value={String(b.id)}>
                      {b.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
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
          <Button onClick={() => create.mutate(undefined)} disabled={create.isPending}>
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
                      {s.start_time} — {s.end_time}
                    </p>
                    {s.branch_name && (
                      <p className="text-xs text-muted-foreground">
                        {s.branch_name}
                      </p>
                    )}
                  </div>
                  {typeof s.employee_count === "number" && (
                    <span className="text-xs text-muted-foreground">
                      <Users className="me-1 inline h-3 w-3" />
                      {s.employee_count}
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
