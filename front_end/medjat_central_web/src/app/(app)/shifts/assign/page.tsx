"use client";

import { useState } from "react";
import { useSearchParams } from "next/navigation";
import { useT } from "@/lib/i18n/use-t";
import { useShifts, useToastMutation } from "@/lib/hooks/use-org";
import { useEmployees } from "@/lib/hooks/use-employees";
import { assignShift, unassignShift } from "@/lib/api/branches";
import {
  LoadingState,
  ErrorState,
  EmptyState,
} from "@/components/ui/states";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Checkbox } from "@/components/ui/checkbox";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";

export default function AssignShiftPage() {
  const { t } = useT();
  const sp = useSearchParams();
  const shiftId = Number(sp.get("id") ?? 0);
  const { data: shifts, isLoading, isError, refetch } = useShifts();
  const { data: employeesData } = useEmployees({ per_page: 500 });
  const shift = (shifts ?? []).find((s) => s.id === shiftId);
  const members = new Set(shift?.members ?? []);
  const employees = Array.isArray(employeesData)
    ? employeesData
    : employeesData?.data ?? [];

  const [selected, setSelected] = useState<number[]>([]);
  const assign = useToastMutation(
    (ids: number[]) => assignShift(shiftId, ids),
    {
      successMessage: t("success"),
      invalidate: [["org", "shifts"] as const],
      onSuccess: () => setSelected([]),
    },
  );
  const unassign = useToastMutation(
    (ids: number[]) => unassignShift(shiftId, ids),
    { successMessage: t("success"), invalidate: [["org", "shifts"] as const] },
  );

  const toggle = (id: number) =>
    setSelected((s) => (s.includes(id) ? s.filter((x) => x !== id) : [...s, id]));

  if (isLoading) return <LoadingState />;
  if (isError) return <ErrorState onRetry={() => refetch()} />;
  if (!shift) return <EmptyState message={t("no_data")} />;

  return (
    <div className="space-y-4">
      <h1 className="text-headline-md font-bold">
        {t("assign_members")} — {shift.name}
      </h1>

      <div className="flex gap-2">
        <Button
          size="sm"
          onClick={() => assign.mutate(selected)}
          disabled={selected.length === 0}
        >
          {t("assign")}
        </Button>
        <Button
          size="sm"
          variant="outline"
          onClick={() => unassign.mutate(selected)}
          disabled={selected.length === 0}
        >
          {t("unassign")}
        </Button>
      </div>

      <p className="text-body-md text-muted-foreground">
        {t("members")}: {members.size}
      </p>

      <div className="rounded-lg border">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead className="w-8"></TableHead>
              <TableHead>{t("employee")}</TableHead>
              <TableHead>{t("status")}</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {employees.map((emp) => {
              const isMember = members.has(emp.id);
              return (
                <TableRow key={emp.id}>
                  <TableCell>
                    <Checkbox
                      checked={selected.includes(emp.id)}
                      onCheckedChange={() => toggle(emp.id)}
                    />
                  </TableCell>
                  <TableCell>
                    {emp.name ?? `${t("employee")} #${emp.id}`}
                  </TableCell>
                  <TableCell>
                    {isMember ? (
                      <Badge variant="default">{t("assigned")}</Badge>
                    ) : (
                      <Badge variant="outline">{t("unassigned")}</Badge>
                    )}
                  </TableCell>
                </TableRow>
              );
            })}
          </TableBody>
        </Table>
      </div>
    </div>
  );
}
