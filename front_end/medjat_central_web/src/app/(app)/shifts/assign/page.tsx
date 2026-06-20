"use client";

import { useState } from "react";
import { useSearchParams } from "next/navigation";
import { useT } from "@/lib/i18n/use-t";
import { useShifts } from "@/lib/hooks/use-org";
import { useToastMutation } from "@/lib/hooks/use-org";
import { assignShift, unassignShift } from "@/lib/api/branches";
import {
  LoadingState,
  ErrorState,
  EmptyState,
} from "@/components/ui/states";
import { Button } from "@/components/ui/button";
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
  const shift = (shifts ?? []).find((s) => s.id === shiftId);
  const members = new Set(shift?.members ?? []);

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
            </TableRow>
          </TableHeader>
          <TableBody>
            {[...members].map((id) => (
              <TableRow key={id}>
                <TableCell>
                  <Checkbox
                    checked={selected.includes(id)}
                    onCheckedChange={() => toggle(id)}
                  />
                </TableCell>
                <TableCell>
                  {t("employee")} #{id}
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </div>
    </div>
  );
}
