"use client";

import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
  DialogTrigger,
  DialogClose,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Pencil } from "lucide-react";
import { useState } from "react";
import { useT } from "@/lib/i18n/use-t";
import { useOverrideLine } from "@/lib/hooks/use-payroll";
import type { Payslip, PayslipLine } from "@/lib/types";

/** Detail view + inline line-override for a payslip. */
export function PayslipDetail({ slip }: { slip: Payslip }) {
  const { t, locale } = useT();
  const fmt = (n: number) =>
    new Intl.NumberFormat(locale === "ar" ? "ar-EG" : "en-GB").format(n);

  return (
    <div className="rounded-lg border p-4">
      <div className="grid grid-cols-2 gap-3 text-body-md sm:grid-cols-3">
        <Field label={t("base_salary")} value={fmt(slip.base)} />
        <Field label={t("allowances")} value={fmt(slip.allowances_total)} />
        <Field label={t("bonuses_field")} value={fmt(slip.bonuses_total)} />
        <Field label={t("deductions")} value={fmt(slip.deductions_total)} />
        <Field label={t("loan_installment")} value={fmt(slip.loan_installment)} />
        <Field
          label={t("net")}
          value={fmt(slip.net)}
          strong
        />
      </div>
      {slip.lines && slip.lines.length > 0 && (
        <div className="mt-4">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>{t("details")}</TableHead>
                <TableHead>{t("amount")}</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {slip.lines.map((l, i) => (
                <TableRow key={i}>
                  <TableCell>{l.label}</TableCell>
                  <TableCell>{fmt(l.amount)}</TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </div>
      )}
    </div>
  );
}

function Field({
  label,
  value,
  strong,
}: {
  label: string;
  value: string;
  strong?: boolean;
}) {
  return (
    <div>
      <p className="text-xs text-muted-foreground">{label}</p>
      <p className={strong ? "text-headline-sm font-bold" : "font-medium"}>
        {value}
      </p>
    </div>
  );
}

/** Dialog to edit a payslip's line items (override_line). */
export function OverrideLineDialog({ slip }: { slip: Payslip }) {
  const { t } = useT();
  const [open, setOpen] = useState(false);
  const [label, setLabel] = useState("");
  const [amount, setAmount] = useState("0");
  const [type, setType] = useState<"earning" | "deduction">("earning");
  const mutate = useOverrideLine();

  const addLine = () => {
    const lines: PayslipLine[] = [
      ...(slip.lines ?? []),
      { label: label || t("details"), amount: Number(amount) || 0, type },
    ];
    mutate.mutate(
      { employeeId: slip.employee_id, month: slip.month, lines },
      { onSuccess: () => setOpen(false) },
    );
  };

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger
        render={
          <Button variant="ghost" size="icon-sm" aria-label={t("override_line")} />
        }
      >
        <Pencil className="h-4 w-4" />
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t("override_line")}</DialogTitle>
        </DialogHeader>
        <div className="space-y-3">
          <div className="space-y-1.5">
            <Label>{t("details")}</Label>
            <Input value={label} onChange={(e) => setLabel(e.target.value)} />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1.5">
              <Label>{t("amount")}</Label>
              <Input
                type="number"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
              />
            </div>
            <div className="space-y-1.5">
              <Label>{t("status")}</Label>
              <select
                className="h-8 w-full rounded-lg border bg-transparent px-2 text-sm"
                value={type}
                onChange={(e) => setType(e.target.value as "earning" | "deduction")}
              >
                <option value="earning">{t("bonus")}</option>
                <option value="deduction">{t("deduction")}</option>
              </select>
            </div>
          </div>
        </div>
        <DialogFooter>
          <DialogClose render={<Button variant="outline" />}>{t("cancel")}</DialogClose>
          <Button onClick={addLine} disabled={mutate.isPending}>
            {mutate.isPending ? t("saving") : t("save")}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
