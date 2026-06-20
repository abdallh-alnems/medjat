"use client";

import { Checkbox } from "@/components/ui/checkbox";
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
import { OverrideLineDialog } from "./payslip-detail";
import type { Payslip, PayslipStatus } from "@/lib/types";

const TONE: Record<PayslipStatus, "default" | "secondary" | "destructive" | "outline"> = {
  draft: "secondary",
  approved: "default",
  paid: "outline",
};

interface Props {
  slips: Payslip[];
  selected: number[];
  onToggle: (id: number) => void;
  onToggleAll: (ids: number[]) => void;
  onApprove: (id: number) => void;
  onRevert: (id: number) => void;
  onMarkPaid: (id: number) => void;
  onPreview: (slip: Payslip) => void;
}

export function PayslipRow({
  slips,
  selected,
  onToggle,
  onToggleAll,
  onApprove,
  onRevert,
  onMarkPaid,
  onPreview,
}: Props) {
  const { t, locale } = useT();
  const fmt = (n: number) =>
    new Intl.NumberFormat(locale === "ar" ? "ar-EG" : "en-GB").format(n);

  const allSelected =
    slips.length > 0 && slips.every((s) => selected.includes(s.id));

  return (
    <div className="rounded-lg border">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead className="w-8">
              <Checkbox
                checked={allSelected}
                onCheckedChange={() => onToggleAll(slips.map((s) => s.id))}
                aria-label={t("all")}
              />
            </TableHead>
            <TableHead>{t("name")}</TableHead>
            <TableHead>{t("net")}</TableHead>
            <TableHead>{t("status")}</TableHead>
            <TableHead>{t("actions")}</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {slips.map((s) => (
            <TableRow key={s.id}>
              <TableCell>
                <Checkbox
                  checked={selected.includes(s.id)}
                  onCheckedChange={() => onToggle(s.id)}
                  aria-label={`${t("name")} ${s.employee_id}`}
                />
              </TableCell>
              <TableCell className="font-medium">
                {s.employee_name ?? `${t("employee")} #${s.employee_id}`}
              </TableCell>
              <TableCell>{fmt(s.net)}</TableCell>
              <TableCell>
                <Badge variant={TONE[s.status]}>{t(s.status === "draft" ? "draft" : s.status === "approved" ? "approve" : "paid")}</Badge>
              </TableCell>
              <TableCell>
                <div className="flex items-center gap-1">
                  <Button variant="ghost" size="sm" onClick={() => onPreview(s)}>
                    {t("view")}
                  </Button>
                  {s.status === "draft" && (
                    <Button variant="ghost" size="sm" onClick={() => onApprove(s.id)}>
                      {t("approve")}
                    </Button>
                  )}
                  {s.status === "approved" && (
                    <>
                      <Button variant="ghost" size="sm" onClick={() => onRevert(s.id)}>
                        {t("revert")}
                      </Button>
                      <Button variant="ghost" size="sm" onClick={() => onMarkPaid(s.id)}>
                        {t("mark_paid")}
                      </Button>
                    </>
                  )}
                  <OverrideLineDialog slip={s} />
                </div>
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  );
}
