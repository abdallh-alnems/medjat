"use client";

import { useState } from "react";
import { useT } from "@/lib/i18n/use-t";
import { usePermissions } from "@/lib/hooks/use-permissions";
import {
  usePayrollSlips,
  useGeneratePayroll,
  useApproveSlip,
  useApproveBulk,
  useRevertSlip,
  useMarkPaid,
  useDisburseAll,
} from "@/lib/hooks/use-payroll";
import { Can } from "@/components/permissions/can";
import {
  LoadingState,
  ErrorState,
  EmptyState,
} from "@/components/ui/states";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { PeriodSelector } from "@/components/payroll/period-selector";
import { PayslipRow } from "@/components/payroll/payslip-row";
import { PayslipDetail } from "@/components/payroll/payslip-detail";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogClose,
} from "@/components/ui/dialog";
import { exportReportToExcel } from "@/lib/export";
import { currentMonth } from "@/lib/utils";
import type { Payslip } from "@/lib/types";
import { Wallet, FileDown } from "lucide-react";

export default function PayrollPage() {
  const { t, locale } = useT();
  const { can } = usePermissions();
  const now = new Date();
  const [month, setMonth] = useState(now.getMonth() + 1);
  const [year, setYear] = useState(now.getFullYear());
  const [selected, setSelected] = useState<number[]>([]);
  const [preview, setPreview] = useState<Payslip | null>(null);

  const period = `${year}-${String(month).padStart(2, "0")}`;

  const { data, isLoading, isError, refetch } = usePayrollSlips({
    month: period,
  });
  const slips = Array.isArray(data) ? data : [];

  const generate = useGeneratePayroll();
  const approve = useApproveSlip();
  const approveBulk = useApproveBulk();
  const revert = useRevertSlip();
  const markPaid = useMarkPaid();
  const disburseAll = useDisburseAll();

  const fmt = (n: number) =>
    new Intl.NumberFormat(locale === "ar" ? "ar-EG" : "en-GB").format(n);

  const totals = slips.reduce(
    (acc, s) => {
      acc.base += s.base;
      acc.net += s.net;
      acc.bonuses += s.bonuses_total;
      acc.deductions += s.deductions_total;
      return acc;
    },
    { base: 0, net: 0, bonuses: 0, deductions: 0 },
  );

  const toggle = (id: number) =>
    setSelected((s) => (s.includes(id) ? s.filter((x) => x !== id) : [...s, id]));
  const toggleAll = (ids: number[]) =>
    setSelected((cur) => (ids.every((id) => cur.includes(id)) ? [] : ids));

  const exportExcel = () => {
    exportReportToExcel({
      title: `${t("payroll")} ${period}`,
      period,
      columns: [
        t("name"),
        t("base_salary"),
        t("allowances"),
        t("deductions"),
        t("net"),
        t("status"),
      ],
      rows: slips.map((s) => [
        s.employee_name ?? String(s.employee_id),
        s.base,
        s.allowances_total,
        s.deductions_total,
        s.net,
        s.status,
      ]),
    });
  };

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between gap-2">
        <h1 className="text-headline-md font-bold">{t("payroll")}</h1>
        <Can permission="manage_payroll">
          <Button
            variant="outline"
            size="sm"
            onClick={() => generate.mutate(period)}
            disabled={generate.isPending}
          >
            <Wallet className="h-4 w-4" />
            {t("generate_payroll")}
          </Button>
        </Can>
      </div>

      <PeriodSelector
        month={month}
        year={year}
        onMonthChange={(m) => {
          setMonth(m);
          setSelected([]);
        }}
        onYearChange={(y) => {
          setYear(y);
          setSelected([]);
        }}
      />

      <div className="grid gap-3 sm:grid-cols-4">
        {[
          { label: t("base_salary"), value: totals.base },
          { label: t("bonuses_field"), value: totals.bonuses },
          { label: t("deductions"), value: totals.deductions },
          { label: t("net"), value: totals.net },
        ].map((c) => (
          <Card key={c.label}>
            <CardContent className="p-4">
              <p className="text-xs text-muted-foreground">{c.label}</p>
              <p className="text-headline-sm font-bold">{fmt(c.value)}</p>
            </CardContent>
          </Card>
        ))}
      </div>

      {selected.length > 0 && (
        <div className="flex items-center gap-2 rounded-lg border bg-muted/40 p-2">
          <span className="text-body-md px-2">
            {selected.length} {t("employees")}
          </span>
          <Button size="sm" onClick={() => approveBulk.mutate(selected)}>
            {t("approve_bulk")}
          </Button>
          <Button
            size="sm"
            variant="outline"
            onClick={() => disburseAll.mutate(period)}
          >
            {t("disburse_all")}
          </Button>
          <Button
            size="sm"
            variant="ghost"
            className="ms-auto"
            onClick={exportExcel}
          >
            <FileDown className="h-4 w-4" />
            {t("excel")}
          </Button>
        </div>
      )}

      {can("manage_payroll") ? (
        isLoading ? (
          <LoadingState />
        ) : isError ? (
          <ErrorState onRetry={() => refetch()} />
        ) : slips.length === 0 ? (
          <EmptyState message={t("no_records")} icon={Wallet} />
        ) : (
          <PayslipRow
            slips={slips}
            selected={selected}
            onToggle={toggle}
            onToggleAll={toggleAll}
            onApprove={(id) => approve.mutate(id)}
            onRevert={(id) => revert.mutate(id)}
            onMarkPaid={(id) => markPaid.mutate(id)}
            onPreview={setPreview}
          />
        )
      ) : (
        <EmptyState message={t("permission_denied")} />
      )}

      <Dialog open={!!preview} onOpenChange={(o) => !o && setPreview(null)}>
        <DialogContent className="sm:max-w-lg">
          <DialogHeader>
            <DialogTitle>{t("payslip")}</DialogTitle>
          </DialogHeader>
          {preview && <PayslipDetail slip={preview} />}
          <DialogClose render={<Button variant="outline" />}>{t("close")}</DialogClose>
        </DialogContent>
      </Dialog>
    </div>
  );
}
