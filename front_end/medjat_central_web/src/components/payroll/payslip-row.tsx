"use client";

import { Fragment, useState } from "react";
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
import type { Payslip } from "@/lib/types";
import { ChevronDown, ChevronRight, Timer } from "lucide-react";

interface Props {
  slips: Payslip[];
  selected: number[];
  onToggle: (id: number) => void;
  onToggleAll: (ids: number[]) => void;
  onApprove: (id: number) => void;
  onRevert: (id: number) => void;
  onMarkPaid: (id: number) => void;
  onDisburse: (slip: Payslip) => void;
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
  onDisburse,
  onPreview,
}: Props) {
  const { t, locale } = useT();
  const [expanded, setExpanded] = useState<Set<number>>(new Set());
  const fmt = (n: number) =>
    new Intl.NumberFormat(locale === "ar" ? "ar-EG" : "en-GB").format(
      Math.round(n),
    );

  const toggleExpand = (empId: number) =>
    setExpanded((cur) => {
      const next = new Set(cur);
      if (next.has(empId)) next.delete(empId);
      else next.add(empId);
      return next;
    });

  // Only generated rows (real id) are selectable for bulk approve/disburse;
  // "live" rows have id 0 and must be generated first.
  const selectableIds = slips.filter((s) => s.id > 0).map((s) => s.id);
  const allSelected =
    selectableIds.length > 0 &&
    selectableIds.every((id) => selected.includes(id));

  return (
    <div className="rounded-lg border">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead className="w-8">
              <Checkbox
                checked={allSelected}
                onCheckedChange={() => onToggleAll(selectableIds)}
                aria-label={t("all")}
              />
            </TableHead>
            <TableHead className="w-8" />
            <TableHead>{t("name")}</TableHead>
            <TableHead>{t("payroll_additions")}</TableHead>
            <TableHead>{t("deductions")}</TableHead>
            <TableHead>{t("net")}</TableHead>
            <TableHead>{t("status")}</TableHead>
            <TableHead>{t("actions")}</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {slips.map((s) => {
            const isOpen = expanded.has(s.employee_id);
            return (
              <Fragment key={s.employee_id}>
                <TableRow>
                  <TableCell>
                    <Checkbox
                      checked={selected.includes(s.id)}
                      disabled={s.id <= 0}
                      onCheckedChange={() => onToggle(s.id)}
                      aria-label={`${t("name")} ${s.employee_id}`}
                    />
                  </TableCell>
                  <TableCell>
                    <Button
                      variant="ghost"
                      size="icon-sm"
                      aria-label={t("details")}
                      onClick={() => toggleExpand(s.employee_id)}
                    >
                      {isOpen ? (
                        <ChevronDown className="h-4 w-4" />
                      ) : (
                        <ChevronRight className="h-4 w-4" />
                      )}
                    </Button>
                  </TableCell>
                  <TableCell className="font-medium">
                    <div className="flex flex-col gap-1">
                      <span>
                        {s.employee_name ?? `${t("employee")} #${s.employee_id}`}
                      </span>
                      {(s.late_total ?? 0) > 0 && (
                        <div className="flex flex-wrap gap-1">
                          <Badge
                            variant="secondary"
                            className="gap-1 text-amber-600"
                          >
                            <Timer className="h-3 w-3" />
                            {t("late")} {fmt(s.late_total ?? 0)}
                          </Badge>
                        </div>
                      )}
                    </div>
                  </TableCell>
                  <TableCell className="text-emerald-600">
                    {s.bonuses_total > 0 ? `+${fmt(s.bonuses_total)}` : "—"}
                  </TableCell>
                  <TableCell className="text-destructive">
                    {s.deductions_total > 0 ? `−${fmt(s.deductions_total)}` : "—"}
                  </TableCell>
                  <TableCell className="font-semibold">{fmt(s.net)}</TableCell>
                  <TableCell>
                    <Badge
                      variant={s.status === "paid" ? "default" : "secondary"}
                      className={
                        s.status === "paid"
                          ? "text-emerald-600"
                          : "text-muted-foreground"
                      }
                    >
                      {s.status === "paid"
                        ? t("status_disbursed")
                        : t("status_not_disbursed")}
                    </Badge>
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
                      {s.status !== "paid" && (
                        <Button variant="ghost" size="sm" onClick={() => onDisburse(s)}>
                          {t("disburse")}
                        </Button>
                      )}
                      <OverrideLineDialog slip={s} />
                    </div>
                  </TableCell>
                </TableRow>
                {isOpen && (
                  <TableRow className="bg-muted/30">
                    <TableCell colSpan={8}>
                      <PayslipBreakdown slip={s} fmt={fmt} />
                    </TableCell>
                  </TableRow>
                )}
              </Fragment>
            );
          })}
        </TableBody>
      </Table>
    </div>
  );
}

function PayslipBreakdown({
  slip,
  fmt,
}: {
  slip: Payslip;
  fmt: (n: number) => string;
}) {
  const { t } = useT();
  const earnings = (slip.lines ?? []).filter((l) => l.type === "earning");
  const deductions = (slip.lines ?? []).filter((l) => l.type === "deduction");

  return (
    <div className="space-y-3 p-1">
      <div className="grid grid-cols-2 gap-x-6 gap-y-1 text-body-md sm:grid-cols-4">
        <Metric label={t("base_salary")} value={fmt(slip.base)} />
        <Metric label={t("bonuses_field")} value={fmt(slip.bonuses_total)} />
        <Metric label={t("deductions")} value={fmt(slip.deductions_total)} />
        <Metric label={t("net")} value={fmt(slip.net)} strong />
      </div>
      {(earnings.length > 0 || deductions.length > 0) && (
        <div className="grid gap-3 sm:grid-cols-2">
          {earnings.length > 0 && (
            <LineList
              title={t("payroll_additions")}
              lines={earnings}
              sign="+"
              tone="text-emerald-600"
              fmt={fmt}
            />
          )}
          {deductions.length > 0 && (
            <LineList
              title={t("deductions")}
              lines={deductions}
              sign="−"
              tone="text-destructive"
              fmt={fmt}
            />
          )}
        </div>
      )}
    </div>
  );
}

function LineList({
  title,
  lines,
  sign,
  tone,
  fmt,
}: {
  title: string;
  lines: { label: string; amount: number }[];
  sign: string;
  tone: string;
  fmt: (n: number) => string;
}) {
  return (
    <div className="rounded-md border bg-background p-2">
      <p className="mb-1 text-xs font-semibold text-muted-foreground">{title}</p>
      <ul className="space-y-1 text-sm">
        {lines.map((l, i) => (
          <li key={i} className="flex items-center justify-between gap-2">
            <span className="truncate">{l.label || "—"}</span>
            <span className={`shrink-0 font-medium ${tone}`}>
              {sign}
              {fmt(l.amount)}
            </span>
          </li>
        ))}
      </ul>
    </div>
  );
}

function Metric({
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
      <p className={strong ? "font-bold" : "font-medium"}>{value}</p>
    </div>
  );
}
