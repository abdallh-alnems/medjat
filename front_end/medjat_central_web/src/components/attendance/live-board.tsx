"use client";

import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { useT } from "@/lib/i18n/use-t";
import type { LiveAttendance } from "@/lib/types";

const TONE: Record<string, "default" | "secondary" | "destructive" | "outline"> = {
  present: "default",
  late: "secondary",
  leave: "outline",
  holiday: "outline",
  absent: "destructive",
};

/** Live/today board rows. Polled by the parent (refetchInterval: 25s). */
export function LiveBoard({ rows }: { rows: LiveAttendance[] }) {
  const { t } = useT();
  return (
    <div className="rounded-lg border">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>{t("name")}</TableHead>
            <TableHead>{t("status")}</TableHead>
            <TableHead>{t("check_in_time")}</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {rows.map((r) => (
            <TableRow key={r.employee_id}>
              <TableCell className="font-medium">{r.employee_name}</TableCell>
              <TableCell>
                <Badge variant={TONE[r.status] ?? "outline"}>{t(r.status)}</Badge>
              </TableCell>
              <TableCell>{r.check_in ?? "—"}</TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  );
}
