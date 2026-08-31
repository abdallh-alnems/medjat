"use client";

import { useState } from "react";
import { useT } from "@/lib/i18n/use-t";
import { usePermissions } from "@/lib/hooks/use-permissions";
import {
  useLivePayrollOverview,
  useApproveSlip,
  useApproveBulk,
  useRevertSlip,
  useMarkPaid,
  useDisburseAll,
  useDisburseEmployee,
} from "@/lib/hooks/use-payroll";
import { Can } from "@/components/permissions/can";
import {
  LoadingState,
  ErrorState,
  EmptyState,
} from "@/components/ui/states";
import { Button } from "@/components/ui/button";
import { MonthCyclePicker } from "@/components/payroll/month-cycle-picker";
import { PayrollSummary } from "@/components/payroll/payroll-summary";
import { PayslipRow } from "@/components/payroll/payslip-row";
import { PayslipDetail } from "@/components/payroll/payslip-detail";
import {
  PayrollToolbar,
  type SortKey,
  type StatusFilter,
} from "@/components/payroll/payroll-toolbar";
import { useBranches, useShifts, useCategories } from "@/lib/hooks/use-org";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogClose,
} from "@/components/ui/dialog";
import { exportReportToExcel } from "@/lib/export";
import {
  defaultLabelMonth,
  isCycleOpen,
  previousLabelMonth,
  cycleLabelContaining,
  isBefore,
  toPeriod,
  type LabelMonth,
} from "@/lib/payroll-cycle";
import type { Payslip } from "@/lib/types";
import type { TKey } from "@/lib/i18n/ar";
import { Wallet, FileDown } from "lucide-react";

type ConfirmTarget = { kind: "all" } | { kind: "one"; slip: Payslip };

export default function PayrollPage() {
  const { t, locale } = useT();
  const { can } = usePermissions();
  const now = new Date();
  const [month, setMonth] = useState(now.getMonth() + 1);
  const [year, setYear] = useState(now.getFullYear());
  const [selected, setSelected] = useState<number[]>([]);
  const [preview, setPreview] = useState<Payslip | null>(null);
  const [confirm, setConfirm] = useState<ConfirmTarget | null>(null);
  const [search, setSearch] = useState("");
  const [sortBy, setSortBy] = useState<SortKey>("name");
  // Sort direction: true = ascending ("من الأقل"), false = descending ("من الأعلى").
  const [sortAsc, setSortAsc] = useState(true);
  const [branchFilter, setBranchFilter] = useState<number | null>(null);
  const [shiftFilter, setShiftFilter] = useState<number | null>(null);
  const [categoryFilter, setCategoryFilter] = useState<number | null>(null);
  const [statusFilter, setStatusFilter] = useState<StatusFilter>(null);
  const [groupByBranch, setGroupByBranch] = useState(false);

  const period = `${year}-${String(month).padStart(2, "0")}`;

  const branches = useBranches().data ?? [];
  const shifts = useShifts().data ?? [];
  const categories = useCategories().data ?? [];

  // Live overview — every active employee with their calculated figures, just
  // like the mobile app (no "generate" step needed for salaries to appear).
  const overviewQ = useLivePayrollOverview(period);
  const overview = overviewQ.data;
  const slips = overview?.slips ?? [];
  const cycleStartDay = overview?.cycleStartDay ?? 1;
  const minHire = overview?.minHireDate ? new Date(overview.minHireDate) : null;

  // On first data load, anchor the picker on the latest *completed* cycle so we
  // open on the month that just ended rather than the still-running one. Done as
  // a guarded state adjustment during render (React's documented pattern) so it
  // happens before paint without an effect's cascading re-render.
  const [anchored, setAnchored] = useState(false);
  if (overview && !anchored) {
    setAnchored(true);
    const target = defaultLabelMonth(
      new Date(),
      overview.cycleStartDay,
      overview.minHireDate ? new Date(overview.minHireDate) : null,
    );
    if (target.month !== month) setMonth(target.month);
    if (target.year !== year) setYear(target.year);
  }

  // Disburse gating, mirroring the app: an open (in-advance) cycle may not be
  // paid until its predecessor is fully settled.
  const lm: LabelMonth = { year, month };
  const cycleOpen = isCycleOpen(lm, cycleStartDay);
  const prevLm = previousLabelMonth(lm);
  const minReach = minHire ? cycleLabelContaining(minHire, cycleStartDay) : null;
  const prevBeforeFloor = minReach ? isBefore(prevLm, minReach) : false;
  const prevQ = useLivePayrollOverview(
    toPeriod(prevLm),
    cycleOpen && !prevBeforeFloor,
  );
  const prevSettled =
    !cycleOpen || prevBeforeFloor
      ? true
      : prevQ.data
        ? prevQ.data.slips.length === 0 ||
          prevQ.data.slips.every((s) => s.status === "paid")
        : false; // unknown → hold
  const disburseBlocked = cycleOpen && !prevSettled;
  const monthLabel = `${month}/${year}`;

  const approve = useApproveSlip();
  const approveBulk = useApproveBulk();
  const revert = useRevertSlip();
  const markPaid = useMarkPaid();
  const disburseAll = useDisburseAll();
  const disburseEmployee = useDisburseEmployee();

  const fmt = (n: number) =>
    new Intl.NumberFormat(locale === "ar" ? "ar-EG" : "en-GB").format(
      Math.round(n),
    );

  // Search + branch/shift/category scope (mirrors the app's _scopedPayrolls);
  // the paid badge is counted here so it ignores the status filter.
  const lower = search.trim().toLowerCase();
  const scoped = slips.filter((s) => {
    if (lower && !(s.employee_name ?? "").toLowerCase().includes(lower))
      return false;
    if (branchFilter !== null && s.branch_id !== branchFilter) return false;
    if (shiftFilter !== null && s.shift_id !== shiftFilter) return false;
    if (
      categoryFilter !== null &&
      !(s.category_ids ?? []).includes(categoryFilter)
    )
      return false;
    return true;
  });
  const paidCount = scoped.filter((s) => s.status === "paid").length;

  const filtered = scoped
    .filter((s) =>
      statusFilter === null
        ? true
        : statusFilter === "paid"
          ? s.status === "paid"
          : s.status !== "paid",
    )
    .sort((a, b) => {
      let cmp: number;
      switch (sortBy) {
        case "net":
          cmp = a.net - b.net;
          break;
        case "deduction":
          cmp = a.deductions_total - b.deductions_total;
          break;
        case "bonus":
          cmp = a.bonuses_total - b.bonuses_total;
          break;
        default:
          cmp = (a.employee_name ?? "").localeCompare(b.employee_name ?? "");
          break;
      }
      return sortAsc ? cmp : -cmp;
    });

  const totals = filtered.reduce(
    (acc, s) => {
      acc.base += s.base;
      acc.net += s.net;
      acc.bonuses += s.bonuses_total;
      acc.deductions += s.deductions_total;
      acc.projected += s.projected_net ?? s.net;
      return acc;
    },
    { base: 0, net: 0, bonuses: 0, deductions: 0, projected: 0 },
  );
  const prevTotal = overview?.previousSummary?.total_net ?? null;
  const delta = prevTotal !== null ? totals.projected - prevTotal : null;

  // Group-by-branch rows: preserve first-seen branch order.
  const groups: { branchId: number | null; name: string; rows: Payslip[] }[] =
    [];
  if (groupByBranch) {
    const byBranch = new Map<number | null, Payslip[]>();
    for (const s of filtered) {
      const b = s.branch_id ?? null;
      if (!byBranch.has(b)) {
        byBranch.set(b, []);
        groups.push({
          branchId: b,
          name: s.branch_name ?? t("branch"),
          rows: byBranch.get(b)!,
        });
      }
      byBranch.get(b)!.push(s);
    }
  }

  const toggle = (id: number) =>
    setSelected((s) => (s.includes(id) ? s.filter((x) => x !== id) : [...s, id]));
  const toggleAll = (ids: number[]) =>
    setSelected((cur) => (ids.every((id) => cur.includes(id)) ? [] : ids));

  const goToPrevMonth = () => {
    setMonth(prevLm.month);
    setYear(prevLm.year);
    setSelected([]);
    setConfirm(null);
  };

  const runDisburse = () => {
    if (!confirm || disburseBlocked) return;
    if (confirm.kind === "all") disburseAll.mutate(period);
    else
      disburseEmployee.mutate({
        employeeId: confirm.slip.employee_id,
        month: period,
      });
    setSelected([]);
    setConfirm(null);
  };

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
      rows: filtered.map((s) => [
        s.employee_name ?? String(s.employee_id),
        s.base,
        s.allowances_total,
        s.deductions_total,
        s.net,
        t(s.status as TKey),
      ]),
    });
  };

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between gap-2">
        <h1 className="text-headline-md font-bold">{t("payroll")}</h1>
        <Can permission="manage_payroll">
          <Button
            size="sm"
            onClick={() => setConfirm({ kind: "all" })}
            disabled={slips.length === 0}
          >
            <Wallet className="h-4 w-4" />
            {t("disburse_month")}
          </Button>
        </Can>
      </div>

      <MonthCyclePicker
        month={month}
        year={year}
        cycleStartDay={cycleStartDay}
        minHireDate={minHire}
        onChange={(m, y) => {
          setMonth(m);
          setYear(y);
          setSelected([]);
        }}
      />

      <PayrollToolbar
        search={search}
        onSearch={setSearch}
        sortBy={sortBy}
        onSort={(v) => {
          setSortBy(v);
          setSortAsc(v === "name"); // A→Z for name, highest-first for amounts
        }}
        sortAsc={sortAsc}
        onToggleDir={() => setSortAsc((a) => !a)}
        branchFilter={branchFilter}
        onBranch={setBranchFilter}
        shiftFilter={shiftFilter}
        onShift={setShiftFilter}
        categoryFilter={categoryFilter}
        onCategory={setCategoryFilter}
        statusFilter={statusFilter}
        onStatus={setStatusFilter}
        groupByBranch={groupByBranch}
        onToggleGroup={() => setGroupByBranch((g) => !g)}
        branches={branches}
        shifts={shifts}
        categories={categories}
      />

      <PayrollSummary
        net={totals.net}
        base={totals.base}
        bonuses={totals.bonuses}
        deductions={totals.deductions}
        delta={delta}
        employeeCount={filtered.length}
        paidCount={paidCount}
        scopedCount={scoped.length}
        currency={overview?.currency ?? "EGP"}
      />

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
            onClick={() => setConfirm({ kind: "all" })}
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
        overviewQ.isLoading ? (
          <LoadingState />
        ) : overviewQ.isError ? (
          <ErrorState onRetry={() => overviewQ.refetch()} />
        ) : filtered.length === 0 ? (
          <EmptyState message={t("no_records")} icon={Wallet} />
        ) : groupByBranch ? (
          <div className="space-y-4">
            {groups.map((g) => {
              const subtotal = g.rows.reduce((s, p) => s + p.net, 0);
              return (
                <div key={g.branchId ?? "none"} className="space-y-1.5">
                  <div className="flex items-center justify-between px-1">
                    <span className="text-body-md font-semibold">
                      {g.name}{" "}
                      <span className="text-muted-foreground">
                        ({g.rows.length})
                      </span>
                    </span>
                    <span className="text-body-md font-semibold">
                      {fmt(subtotal)}
                    </span>
                  </div>
                  <PayslipRow
                    slips={g.rows}
                    selected={selected}
                    onToggle={toggle}
                    onToggleAll={toggleAll}
                    onApprove={(id) => approve.mutate(id)}
                    onRevert={(id) => revert.mutate(id)}
                    onMarkPaid={(id) => markPaid.mutate(id)}
                    onDisburse={(s) => setConfirm({ kind: "one", slip: s })}
                    onPreview={setPreview}
                  />
                </div>
              );
            })}
          </div>
        ) : (
          <PayslipRow
            slips={filtered}
            selected={selected}
            onToggle={toggle}
            onToggleAll={toggleAll}
            onApprove={(id) => approve.mutate(id)}
            onRevert={(id) => revert.mutate(id)}
            onMarkPaid={(id) => markPaid.mutate(id)}
            onDisburse={(s) => setConfirm({ kind: "one", slip: s })}
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

      <Dialog open={!!confirm} onOpenChange={(o) => !o && setConfirm(null)}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>
              {confirm?.kind === "one" ? t("disburse_salary") : t("disburse_month")}
            </DialogTitle>
          </DialogHeader>
          <div className="space-y-3 text-body-md">
            <p className="text-muted-foreground">
              {t("month")}: {monthLabel}
              {confirm?.kind === "one" && confirm.slip.employee_name
                ? ` — ${confirm.slip.employee_name}`
                : ""}
            </p>
            <p>{confirm?.kind === "one" ? t("disburse_one_q") : t("disburse_confirm_q")}</p>
            {disburseBlocked ? (
              <div className="rounded-md border border-destructive/40 bg-destructive/10 p-3 text-sm text-destructive">
                {t("disburse_prev_required")}
              </div>
            ) : (
              cycleOpen && (
                <div className="rounded-md border border-amber-500/40 bg-amber-500/10 p-3 text-sm text-amber-700 dark:text-amber-400">
                  {t("mid_cycle_warning")}
                </div>
              )
            )}
          </div>
          <div className="flex justify-end gap-2">
            <Button variant="outline" onClick={() => setConfirm(null)}>
              {t("cancel")}
            </Button>
            {disburseBlocked ? (
              <Button onClick={goToPrevMonth}>{t("go_to_previous_month")}</Button>
            ) : (
              <Button
                onClick={runDisburse}
                disabled={disburseAll.isPending || disburseEmployee.isPending}
              >
                {t("disburse")}
              </Button>
            )}
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
}
