"use client";

import { useSearchParams } from "next/navigation";
import { useT } from "@/lib/i18n/use-t";
import { useShifts } from "@/lib/hooks/use-org";
import {
  LoadingState,
  ErrorState,
  EmptyState,
} from "@/components/ui/states";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";

/** Read-only list of members assigned to a shift. */
export default function ShiftMembersPage() {
  const { t } = useT();
  const sp = useSearchParams();
  const shiftId = Number(sp.get("id") ?? 0);
  const { data: shifts, isLoading, isError, refetch } = useShifts();
  const shift = (shifts ?? []).find((s) => s.id === shiftId);
  const members = shift?.members ?? [];

  if (isLoading) return <LoadingState />;
  if (isError) return <ErrorState onRetry={() => refetch()} />;
  if (!shift) return <EmptyState message={t("no_data")} />;

  return (
    <div className="space-y-4">
      <h1 className="text-headline-md font-bold">
        {t("members")} — {shift.name}
      </h1>
      {members.length === 0 ? (
        <EmptyState message={t("no_data")} />
      ) : (
        <div className="rounded-lg border">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>{t("employee")}</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {members.map((id) => (
                <TableRow key={id}>
                  <TableCell>
                    {t("employee")} #{id}
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </div>
      )}
    </div>
  );
}
