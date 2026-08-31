"use client";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { useT } from "@/lib/i18n/use-t";
import type { BreakStatus, BreakRequest } from "@/lib/types";
import type { TKey } from "@/lib/i18n/ar";

const TONE: Record<BreakStatus, "default" | "secondary" | "destructive" | "outline"> = {
  pending: "secondary",
  approved: "default",
  rejected: "destructive",
  postponed: "outline",
};

const STATUS_KEY: Record<BreakStatus, TKey> = {
  pending: "pending",
  approved: "approve",
  rejected: "rejected",
  postponed: "postpone",
};

interface Props {
  rows: BreakRequest[];
  onApprove: (id: number) => void;
  onReject: (id: number) => void;
  onPostpone: (id: number) => void;
}

export function BreakRow({ rows, onApprove, onReject, onPostpone }: Props) {
  const { t } = useT();
  return (
    <div className="rounded-lg border">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>{t("name")}</TableHead>
            <TableHead>{t("date")}</TableHead>
            <TableHead>{t("time")}</TableHead>
            <TableHead>{t("status")}</TableHead>
            <TableHead>{t("actions")}</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {rows.map((b) => (
            <TableRow key={b.id}>
              <TableCell className="font-medium">
                {b.employee_name ?? `${t("employee")} #${b.employee_id}`}
              </TableCell>
              <TableCell>{b.date}</TableCell>
              <TableCell>
                {b.from_time} — {b.to_time}
              </TableCell>
              <TableCell>
                <Badge variant={TONE[b.status]}>{t(STATUS_KEY[b.status])}</Badge>
              </TableCell>
              <TableCell>
                {b.status === "pending" && (
                  <div className="flex gap-1">
                    <Button variant="ghost" size="sm" onClick={() => onApprove(b.id)}>
                      {t("approve")}
                    </Button>
                    <Button variant="ghost" size="sm" onClick={() => onReject(b.id)}>
                      {t("reject_document")}
                    </Button>
                    <Button variant="ghost" size="sm" onClick={() => onPostpone(b.id)}>
                      {t("postpone")}
                    </Button>
                  </div>
                )}
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  );
}
