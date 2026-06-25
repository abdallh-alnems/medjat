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
import type { LeaveStatus, LeaveRequest } from "@/lib/types";
import type { TKey } from "@/lib/i18n/ar";

const TONE: Record<LeaveStatus, "default" | "secondary" | "destructive" | "outline"> = {
  pending: "secondary",
  approved: "default",
  rejected: "destructive",
  absence: "outline",
};

const STATUS_KEY: Record<LeaveStatus, TKey> = {
  pending: "pending",
  approved: "approve",
  rejected: "rejected",
  absence: "absent",
};

interface Props {
  rows: LeaveRequest[];
  onApprove: (id: number) => void;
  onReject: (id: number) => void;
}

export function LeaveRow({ rows, onApprove, onReject }: Props) {
  const { t } = useT();
  return (
    <div className="rounded-lg border">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>{t("name")}</TableHead>
            <TableHead>{t("leave_type")}</TableHead>
            <TableHead>{t("from")}</TableHead>
            <TableHead>{t("to")}</TableHead>
            <TableHead>{t("days")}</TableHead>
            <TableHead>{t("status")}</TableHead>
            <TableHead>{t("actions")}</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {rows.map((l) => (
            <TableRow key={l.id}>
              <TableCell className="font-medium">
                {l.employee_name ?? `${t("employee")} #${l.employee_id}`}
              </TableCell>
              <TableCell>{t(l.type as TKey)}</TableCell>
              <TableCell>{l.from}</TableCell>
              <TableCell>{l.to}</TableCell>
              <TableCell>{l.days}</TableCell>
              <TableCell>
                <Badge variant={TONE[l.status]}>{t(STATUS_KEY[l.status])}</Badge>
              </TableCell>
              <TableCell>
                {l.status === "pending" && (
                  <div className="flex gap-1">
                    <Button variant="ghost" size="sm" onClick={() => onApprove(l.id)}>
                      {t("approve")}
                    </Button>
                    <Button variant="ghost" size="sm" onClick={() => onReject(l.id)}>
                      {t("reject_document")}
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
