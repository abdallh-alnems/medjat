"use client";

import Link from "next/link";
import {
  CheckCircle2,
  XCircle,
  Clock,
  CalendarOff,
  Hourglass,
  Coffee,
  FileWarning,
} from "lucide-react";
import { useDashboardOverview } from "@/lib/hooks/use-dashboard";
import { useT } from "@/lib/i18n/use-t";
import {
  LoadingState,
  ErrorState,
  EmptyState,
} from "@/components/ui/states";
import { StatCard } from "@/components/dashboard/stat-card";
import {
  PayrollSummary,
  AttendanceSummary,
} from "@/components/dashboard/attendance-payroll-summary";
import {
  BranchComparison,
  CategoryDistribution,
} from "@/components/dashboard/branch-comparison";

export default function DashboardPage() {
  const { t } = useT();
  const { data, isLoading, isError, refetch } = useDashboardOverview();

  if (isLoading) return <LoadingState />;
  if (isError || !data) return <ErrorState onRetry={() => refetch()} />;

  const totalToday = data.present + data.absent + data.late + data.on_leave;

  return (
    <div className="space-y-4">
      <h1 className="text-headline-md font-bold">{t("dashboard")}</h1>

      {/* Today's counts */}
      <section className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <StatCard
          icon={CheckCircle2}
          label={t("present_today")}
          value={data.present}
          tone="success"
        />
        <StatCard
          icon={XCircle}
          label={t("absent_today")}
          value={data.absent}
          tone="destructive"
        />
        <StatCard
          icon={Clock}
          label={t("late_today")}
          value={data.late}
          tone="warning"
        />
        <StatCard
          icon={CalendarOff}
          label={t("on_leave_today")}
          value={data.on_leave}
        />
      </section>

      {/* Summary + attendance rate */}
      <section className="grid gap-3 lg:grid-cols-3">
        <AttendanceSummary
          rate={data.attendance_rate}
          present={data.present}
          total={totalToday}
        />
        <PayrollSummary data={data.payroll} />
        <div className="card-flat flex flex-col gap-3">
          <Link
            href="/leaves"
            className="flex items-center justify-between rounded-lg p-2 hover:bg-muted"
          >
            <span className="flex items-center gap-2 text-body-md">
              <Hourglass className="h-4 w-4 text-warning" />
              {t("pending_leaves")}
            </span>
            <span className="text-headline-sm font-bold">
              {data.pending_leaves}
            </span>
          </Link>
          <Link
            href="/breaks"
            className="flex items-center justify-between rounded-lg p-2 hover:bg-muted"
          >
            <span className="flex items-center gap-2 text-body-md">
              <Coffee className="h-4 w-4 text-brand" />
              {t("pending_breaks")}
            </span>
            <span className="text-headline-sm font-bold">
              {data.pending_breaks}
            </span>
          </Link>
          <Link
            href="/dashboard/expiring-compliance"
            className="flex items-center justify-between rounded-lg p-2 hover:bg-muted"
          >
            <span className="flex items-center gap-2 text-body-md">
              <FileWarning className="h-4 w-4 text-destructive" />
              {t("expiring_compliance")}
            </span>
            <span className="text-headline-sm font-bold">
              {data.expiring_compliance}
            </span>
          </Link>
        </div>
      </section>

      {/* Charts */}
      <section className="grid gap-3 lg:grid-cols-2">
        {data.branch_comparison.length > 0 ? (
          <BranchComparison data={data.branch_comparison} />
        ) : (
          <EmptyState message={t("no_data")} />
        )}
        {data.category_distribution.length > 0 ? (
          <CategoryDistribution data={data.category_distribution} />
        ) : (
          <EmptyState message={t("no_data")} />
        )}
      </section>
    </div>
  );
}
