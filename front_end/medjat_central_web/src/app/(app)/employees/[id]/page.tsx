"use client";

import { use, useState } from "react";
import { useRouter, notFound } from "next/navigation";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { useEmployee, useFinancialSummary, useAttendanceHistory, useYearToDate } from "@/lib/hooks/use-employees";
import { useBranches } from "@/lib/hooks/use-org";
import { useT } from "@/lib/i18n/use-t";
import type { TKey } from "@/lib/i18n/ar";
import { usePermissions } from "@/lib/hooks/use-permissions";
import { useToastMutation } from "@/lib/hooks/use-org";
import {
  updateEmployee,
  getSuspensions,
  suspendEmployee,
  endSuspension,
} from "@/lib/api/employees";
import type { SuspensionPayMode } from "@/lib/types";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { ActivationCard } from "@/components/employee/activation-card";
import { CrewSupervisorCard } from "@/components/employee/crew-supervisor-card";
import { FinancialAdjustments } from "@/components/employee/financial-adjustments";
import { addWarning, deleteWarning, listWarnings } from "@/lib/api/warnings";
import {
  listPerformanceReviews,
  createPerformanceReview,
  deletePerformanceReview,
} from "@/lib/api/performance";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import {
  LoadingState,
  ErrorState,
  EmptyState,
} from "@/components/ui/states";
import { formatEGP, formatDate, currentMonth } from "@/lib/utils";
import { useUIStore } from "@/lib/stores/ui-store";
import {
  ArrowRight,
  FileText,
  Banknote,
  AlertTriangle,
  Star,
  Trash2,
} from "lucide-react";
import Link from "next/link";

export default function EmployeeDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = use(params);
  const employeeId = Number(id);
  const router = useRouter();
  const { t } = useT();
  const locale = useUIStore((s) => s.locale);
  const { can } = usePermissions();

  if (!id || Number.isNaN(employeeId)) notFound();

  const { data: employee, isLoading, isError, refetch } = useEmployee(employeeId);
  const { data: branches } = useBranches();
  const branchName =
    branches?.find((b) => b.id === employee?.branch_id)?.name ?? "—";

  const financials = useFinancialSummary(employeeId, currentMonth());
  const ytd = useYearToDate(employeeId, new Date().getFullYear());
  const history = useAttendanceHistory(employeeId, { month: currentMonth() });

  const reviews = useQuery({
    queryKey: ["performance", employeeId],
    queryFn: () => listPerformanceReviews(employeeId),
  });

  const warnings = useQuery({
    queryKey: ["warnings", employeeId],
    queryFn: () => listWarnings(employeeId),
  });

  const update = useToastMutation(
    (data: Parameters<typeof updateEmployee>[1]) => updateEmployee(employeeId, data),
    {
      successMessage: t("saved"),
      invalidate: [["employees", "detail", employeeId]],
    },
  );

  const warnMutation = useToastMutation(
    (args: { reason: string }) => addWarning(employeeId, args.reason),
    { successMessage: t("saved"), invalidate: [["employees", "detail", employeeId]] },
  );
  const warnDelete = useToastMutation(
    (wid: number) => deleteWarning(wid),
    { invalidate: [["employees", "detail", employeeId]] },
  );
  const reviewCreate = useToastMutation(
    (args: { period: string; rating: number; notes?: string }) =>
      createPerformanceReview(employeeId, args),
    {
      successMessage: t("saved"),
      invalidate: [["performance", employeeId]],
    },
  );
  const reviewDelete = useToastMutation(
    (rid: number) => deletePerformanceReview(rid),
    { invalidate: [["performance", employeeId]] },
  );

  if (isLoading) return <LoadingState />;
  if (isError || !employee) return <ErrorState onRetry={() => refetch()} />;

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-2">
        <button onClick={() => router.back()} className="text-brand">
          <ArrowRight className="h-4 w-4" />
        </button>
        <h1 className="flex-1 text-headline-md font-bold">{employee.name}</h1>
        <Badge>{t(employee.status as TKey)}</Badge>
      </div>

      <div className="flex flex-wrap gap-2">
        <Button variant="outline" size="sm" render={<Link href={`/employees/${employeeId}/documents`} />}>
          <FileText className="h-4 w-4" /> {t("documents")}
        </Button>
        {can("manage_employees") && (
          <Button variant="outline" size="sm" render={<Link href={`/employees/${employeeId}/settlement`} />}>
            <Banknote className="h-4 w-4" /> {t("settlement")}
          </Button>
        )}
      </div>

      <Tabs defaultValue="profile">
        <TabsList className="flex-wrap">
          <TabsTrigger value="profile">{t("employee_details")}</TabsTrigger>
          <TabsTrigger value="financials">{t("financial_summary")}</TabsTrigger>
          <TabsTrigger value="attendance">{t("attendance_history")}</TabsTrigger>
          <TabsTrigger value="warnings">{t("warnings")}</TabsTrigger>
          <TabsTrigger value="reviews">{t("performance_reviews")}</TabsTrigger>
          <TabsTrigger value="suspensions">{t("suspensions")}</TabsTrigger>
        </TabsList>

        {/* Profile / edit */}
        <TabsContent value="profile" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle className="text-title-lg">{t("employee_details")}</CardTitle>
            </CardHeader>
            <CardContent>
              <ProfileForm
                employee={employee}
                branchName={branchName}
                canEdit={can("manage_employees")}
                onSave={(data) => update.mutate(data)}
                busy={update.isPending}
              />
            </CardContent>
          </Card>

          <CrewSupervisorCard
            employee={employee}
            canEdit={can("manage_employees")}
          />

          {employee.leave_balance && (
            <Card>
              <CardHeader>
                <CardTitle className="text-title-lg">
                  {t("leave_balance")}
                  {employee.leave_balance.year
                    ? ` — ${employee.leave_balance.year}`
                    : ""}
                </CardTitle>
              </CardHeader>
              <CardContent className="grid grid-cols-2 gap-3 sm:grid-cols-5">
                <Stat
                  label={t("entitlement")}
                  value={String(employee.leave_balance.entitlement_days ?? 0)}
                />
                <Stat
                  label={t("carried_over")}
                  value={String(employee.leave_balance.carried_over_days ?? 0)}
                />
                <Stat
                  label={t("total")}
                  value={String(employee.leave_balance.total_days ?? 0)}
                />
                <Stat
                  label={t("leave_used")}
                  value={String(employee.leave_balance.used_days ?? 0)}
                />
                <Stat
                  label={t("remaining")}
                  value={String(employee.leave_balance.remaining_days ?? 0)}
                />
              </CardContent>
            </Card>
          )}

          {can("manage_employees") && employee.status !== "terminated" && (
            <ActivationCard employeeId={employeeId} />
          )}
        </TabsContent>

        {/* Financials */}
        <TabsContent value="financials" className="space-y-4">
          <Card>
            <CardContent className="grid gap-3 py-4 sm:grid-cols-2">
              <Stat label={t("net")} value={formatEGP(financials.data?.net ?? 0, locale)} />
              <Stat label={t("ytd")} value={formatEGP(ytd.data?.net ?? 0, locale)} />
            </CardContent>
          </Card>

          {can("manage_payroll") && (
            <FinancialAdjustments employeeId={employeeId} />
          )}
        </TabsContent>

        {/* Attendance history */}
        <TabsContent value="attendance">
          <Card>
            <CardContent className="py-4">
              {history.isLoading ? (
                <LoadingState />
              ) : !history.data || history.data.length === 0 ? (
                <EmptyState message={t("no_records")} />
              ) : (
                <ul className="divide-y">
                  {history.data.map((r) => (
                    <li key={`${r.employee_id}-${r.date}`} className="flex items-center justify-between py-2">
                      <div>
                        <p className="font-medium">{formatDate(r.date, locale)}</p>
                        <p className="text-label-sm text-muted-foreground">{t(r.status as TKey)}</p>
                      </div>
                      <span className="text-label-md text-muted-foreground">
                        {r.check_in ?? "—"} → {r.check_out ?? "—"}
                      </span>
                    </li>
                  ))}
                </ul>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        {/* Warnings */}
        <TabsContent value="warnings">
          <Card>
            <CardHeader>
              <CardTitle className="text-title-lg">{t("warnings")}</CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              {can("manage_employees") && (
                <WarningForm
                  onAdd={(reason) => warnMutation.mutate({ reason })}
                  busy={warnMutation.isPending}
                />
              )}
              {!warnings.data || warnings.data.length === 0 ? (
                <EmptyState message={t("no_data")} />
              ) : (
                <ul className="divide-y">
                  {warnings.data.map((w) => (
                    <li key={w.id} className="flex items-center justify-between py-2">
                      <div>
                        <p className="flex items-center gap-2 font-medium">
                          <AlertTriangle className="h-4 w-4 text-warning" />
                          {w.reason}
                        </p>
                        <p className="text-label-sm text-muted-foreground">
                          {formatDate(w.date, locale)}
                        </p>
                      </div>
                      {can("manage_employees") && (
                        <Button variant="ghost" size="icon-sm" onClick={() => warnDelete.mutate(w.id)}>
                          <Trash2 className="h-4 w-4" />
                        </Button>
                      )}
                    </li>
                  ))}
                </ul>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        {/* Performance reviews */}
        <TabsContent value="reviews">
          <Card>
            <CardHeader>
              <CardTitle className="text-title-lg">{t("performance_reviews")}</CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              {can("manage_employees") && (
                <ReviewForm
                  onAdd={(args) => reviewCreate.mutate(args)}
                  busy={reviewCreate.isPending}
                />
              )}
              {reviews.isLoading ? (
                <LoadingState />
              ) : !reviews.data || reviews.data.length === 0 ? (
                <EmptyState message={t("no_data")} />
              ) : (
                <ul className="divide-y">
                  {reviews.data.map((r) => (
                    <li key={r.id} className="flex items-center justify-between py-2">
                      <div>
                        <p className="flex items-center gap-2 font-medium">
                          <Star className="h-4 w-4 text-warning" />
                          {r.period} — {r.rating}/5
                        </p>
                        {r.notes && (
                          <p className="text-label-sm text-muted-foreground">{r.notes}</p>
                        )}
                      </div>
                      {can("manage_employees") && (
                        <Button variant="ghost" size="icon-sm" onClick={() => reviewDelete.mutate(r.id)}>
                          <Trash2 className="h-4 w-4" />
                        </Button>
                      )}
                    </li>
                  ))}
                </ul>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        {/* Suspensions */}
        <TabsContent value="suspensions">
          <SuspensionsTab
            employeeId={employeeId}
            canManage={can("manage_employees")}
          />
        </TabsContent>
      </Tabs>
    </div>
  );
}

function SuspensionsTab({
  employeeId,
  canManage,
}: {
  employeeId: number;
  canManage: boolean;
}) {
  const { t } = useT();
  const locale = useUIStore((s) => s.locale);
  const qc = useQueryClient();

  const { data, isLoading } = useQuery({
    queryKey: ["suspensions", employeeId],
    queryFn: () => getSuspensions(employeeId),
  });

  const invalidate = () => {
    qc.invalidateQueries({ queryKey: ["suspensions", employeeId] });
    qc.invalidateQueries({ queryKey: ["employees", "detail", employeeId] });
  };

  const suspend = useToastMutation(
    (args: Parameters<typeof suspendEmployee>[0]) => suspendEmployee(args),
    { successMessage: t("saved"), onSuccess: invalidate },
  );
  const end = useToastMutation(() => endSuspension(employeeId), {
    successMessage: t("saved"),
    onSuccess: invalidate,
  });

  const active = data?.active ?? null;
  const history = data?.suspensions ?? [];

  const payLabel = (m: SuspensionPayMode): TKey =>
    m === "partial"
      ? "suspension_pay_partial"
      : m === "full"
        ? "suspension_pay_full"
        : "suspension_pay_unpaid";

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-title-lg">{t("suspension_history")}</CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        {isLoading ? (
          <LoadingState />
        ) : (
          <>
            {active ? (
              <div className="space-y-2 rounded-lg border border-warning/40 bg-warning/5 p-3">
                <p className="flex items-center gap-2 font-medium text-warning">
                  <AlertTriangle className="h-4 w-4" />
                  {t("suspension_active_title")}
                </p>
                <p className="text-body-md">{active.reason}</p>
                <p className="text-label-sm text-muted-foreground">
                  {formatDate(active.start_date, locale)} →{" "}
                  {active.end_date
                    ? formatDate(active.end_date, locale)
                    : t("suspension_open_ended_short")}{" "}
                  · {t(payLabel(active.pay_mode))}
                  {active.pay_mode === "partial" && active.pay_percentage
                    ? ` (${active.pay_percentage}%)`
                    : ""}
                </p>
                {canManage && (
                  <div className="pt-1">
                    <p className="mb-2 text-label-sm text-muted-foreground">
                      {t("end_suspension_hint")}
                    </p>
                    <Button
                      variant="outline"
                      size="sm"
                      disabled={end.isPending}
                      onClick={() => end.mutate(undefined)}
                    >
                      {t("end_suspension")}
                    </Button>
                  </div>
                )}
              </div>
            ) : (
              canManage && (
                <SuspendForm
                  onSubmit={(args) => suspend.mutate(args)}
                  busy={suspend.isPending}
                  employeeId={employeeId}
                />
              )
            )}

            {history.length === 0 ? (
              <EmptyState message={t("no_suspensions")} />
            ) : (
              <ul className="divide-y">
                {history.map((s) => (
                  <li key={s.id} className="py-2">
                    <div className="flex items-center justify-between">
                      <p className="font-medium">{s.reason}</p>
                      <Badge
                        variant={s.status === "active" ? "default" : "secondary"}
                      >
                        {s.status === "active" ? t("active") : t("inactive")}
                      </Badge>
                    </div>
                    <p className="text-label-sm text-muted-foreground">
                      {formatDate(s.start_date, locale)} →{" "}
                      {s.end_date
                        ? formatDate(s.end_date, locale)
                        : t("suspension_open_ended_short")}{" "}
                      · {t(payLabel(s.pay_mode))}
                      {s.created_by_name
                        ? ` · ${t("suspension_issued_by")}: ${s.created_by_name}`
                        : ""}
                    </p>
                  </li>
                ))}
              </ul>
            )}
          </>
        )}
      </CardContent>
    </Card>
  );
}

function SuspendForm({
  onSubmit,
  busy,
  employeeId,
}: {
  onSubmit: (args: Parameters<typeof suspendEmployee>[0]) => void;
  busy: boolean;
  employeeId: number;
}) {
  const { t } = useT();
  const [reason, setReason] = useState("");
  const [payMode, setPayMode] = useState<SuspensionPayMode>("unpaid");
  const [payPercentage, setPayPercentage] = useState("50");
  const [startDate, setStartDate] = useState(
    () => new Date().toISOString().slice(0, 10),
  );
  const [endDate, setEndDate] = useState("");

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        onSubmit({
          employee_id: employeeId,
          reason: reason.trim(),
          pay_mode: payMode,
          pay_percentage:
            payMode === "partial" ? Number(payPercentage) || 0 : null,
          start_date: startDate,
          end_date: endDate || null,
        });
      }}
      className="space-y-3 rounded-lg border p-3"
    >
      <p className="font-medium">{t("suspend_employee")}</p>
      <div className="space-y-1.5">
        <Label>{t("suspension_reason")}</Label>
        <Input
          value={reason}
          onChange={(e) => setReason(e.target.value)}
          required
        />
      </div>
      <div className="grid gap-3 sm:grid-cols-2">
        <div className="space-y-1.5">
          <Label>{t("suspension_pay_treatment")}</Label>
          <Select
            value={payMode}
            onValueChange={(v) => setPayMode((v ?? "unpaid") as SuspensionPayMode)}
          >
            <SelectTrigger className="w-full">
              <SelectValue>
                {(v) =>
                  t(
                    v === "partial"
                      ? "suspension_pay_partial"
                      : v === "full"
                        ? "suspension_pay_full"
                        : "suspension_pay_unpaid",
                  )
                }
              </SelectValue>
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="unpaid">
                {t("suspension_pay_unpaid")}
              </SelectItem>
              <SelectItem value="partial">
                {t("suspension_pay_partial")}
              </SelectItem>
              <SelectItem value="full">{t("suspension_pay_full")}</SelectItem>
            </SelectContent>
          </Select>
        </div>
        {payMode === "partial" && (
          <div className="space-y-1.5">
            <Label>{t("suspension_pay_percentage")}</Label>
            <Input
              type="number"
              min={1}
              max={99}
              value={payPercentage}
              onChange={(e) => setPayPercentage(e.target.value)}
            />
          </div>
        )}
      </div>
      <div className="grid gap-3 sm:grid-cols-2">
        <div className="space-y-1.5">
          <Label>{t("suspension_start_date")}</Label>
          <Input
            type="date"
            value={startDate}
            onChange={(e) => setStartDate(e.target.value)}
          />
        </div>
        <div className="space-y-1.5">
          <Label>{t("suspension_end_date")}</Label>
          <Input
            type="date"
            value={endDate}
            onChange={(e) => setEndDate(e.target.value)}
          />
        </div>
      </div>
      <div className="flex justify-end">
        <Button type="submit" disabled={busy || !reason.trim()}>
          {t("suspend")}
        </Button>
      </div>
    </form>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="card-flat">
      <p className="text-label-md text-muted-foreground">{label}</p>
      <p className="text-headline-sm font-bold">{value}</p>
    </div>
  );
}

function ProfileForm({
  employee,
  branchName,
  canEdit,
  onSave,
  busy,
}: {
  employee: { name: string; phone?: string | null; email?: string | null; job_title?: string | null; base_salary: number };
  branchName: string;
  canEdit: boolean;
  onSave: (data: Record<string, unknown>) => void;
  busy: boolean;
}) {
  const { t } = useT();
  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        const fd = new FormData(e.currentTarget);
        onSave({
          name: fd.get("name"),
          phone: fd.get("phone"),
          email: fd.get("email"),
          job_title: fd.get("job_title"),
          base_salary: Number(fd.get("base_salary")) || 0,
        });
      }}
      className="grid gap-3 sm:grid-cols-2"
    >
      <Labeled label={t("name")}>
        <Input name="name" defaultValue={employee.name} disabled={!canEdit} />
      </Labeled>
      <Labeled label={t("phone")}>
        <Input name="phone" defaultValue={employee.phone ?? ""} disabled={!canEdit} />
      </Labeled>
      <Labeled label={t("email")}>
        <Input name="email" defaultValue={employee.email ?? ""} disabled={!canEdit} />
      </Labeled>
      <Labeled label={t("job_title")}>
        <Input name="job_title" defaultValue={employee.job_title ?? ""} disabled={!canEdit} />
      </Labeled>
      <Labeled label={t("base_salary_field")}>
        <Input name="base_salary" type="number" defaultValue={employee.base_salary} disabled={!canEdit} />
      </Labeled>
      <Labeled label={t("branch")}>
        <Input value={branchName} disabled />
      </Labeled>
      {canEdit && (
        <div className="sm:col-span-2 flex justify-end">
          <Button type="submit" disabled={busy}>
            {t("save")}
          </Button>
        </div>
      )}
    </form>
  );
}

function WarningForm({
  onAdd,
  busy,
}: {
  onAdd: (reason: string) => void;
  busy: boolean;
}) {
  const { t } = useT();
  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        const fd = new FormData(e.currentTarget);
        onAdd(String(fd.get("reason") ?? ""));
        (e.currentTarget as HTMLFormElement).reset();
      }}
      className="flex gap-2"
    >
      <Input name="reason" placeholder={t("reason")} required />
      <Button type="submit" disabled={busy}>
        {t("add")}
      </Button>
    </form>
  );
}

function ReviewForm({
  onAdd,
  busy,
}: {
  onAdd: (a: { period: string; rating: number; notes?: string }) => void;
  busy: boolean;
}) {
  const { t } = useT();
  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        const fd = new FormData(e.currentTarget);
        onAdd({
          period: String(fd.get("period") ?? ""),
          rating: Number(fd.get("rating")),
          notes: String(fd.get("notes") ?? "") || undefined,
        });
        (e.currentTarget as HTMLFormElement).reset();
      }}
      className="grid gap-2 sm:grid-cols-3"
    >
      <Input name="period" placeholder={t("period")} required />
      <Input name="rating" type="number" min={1} max={5} defaultValue={3} required />
      <Input name="notes" placeholder={t("notes")} />
      <div className="sm:col-span-3 flex justify-end">
        <Button type="submit" disabled={busy}>
          {t("add")}
        </Button>
      </div>
    </form>
  );
}

function Labeled({
  label,
  children,
}: {
  label: string;
  children: React.ReactNode;
}) {
  return (
    <div className="space-y-1.5">
      <Label>{label}</Label>
      {children}
    </div>
  );
}
