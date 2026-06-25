"use client";

import Link from "next/link";
import {
  CheckCircle2,
  XCircle,
  Clock,
  CalendarOff,
  Hourglass,
  Coffee,
  Wallet,
  FileWarning,
  PackageOpen,
  CheckCheck,
  ChevronLeft,
} from "lucide-react";
import { useDashboardOverview } from "@/lib/hooks/use-dashboard";
import { useT } from "@/lib/i18n/use-t";
import { useUIStore } from "@/lib/stores/ui-store";
import { useAuthStore } from "@/lib/stores/auth-store";
import { LoadingState, ErrorState } from "@/components/ui/states";
import { StatCard } from "@/components/dashboard/stat-card";
import { PayrollSummary } from "@/components/dashboard/attendance-payroll-summary";
import { BranchPerformanceList } from "@/components/dashboard/branch-performance";

export default function DashboardPage() {
  const { t } = useT();
  const locale = useUIStore((s) => s.locale);
  const user = useAuthStore((s) => s.user);
  const { data, isLoading, isError, refetch } = useDashboardOverview();

  if (isLoading) return <LoadingState />;
  if (isError || !data) return <ErrorState onRetry={() => refetch()} />;

  const firstName = user?.name?.trim().split(/\s+/)[0] ?? t("admin_panel");
  const today = new Intl.DateTimeFormat(locale === "ar" ? "ar-EG" : "en-US", {
    weekday: "long",
    day: "numeric",
    month: "long",
    year: "numeric",
  }).format(new Date());

  // Each tally's share of the in-scope active headcount (mirrors the app).
  const active = data.active_in_scope || 0;
  const pct = (v: number) =>
    active > 0 ? `${((v / active) * 100).toFixed(1)}% ${t("of_active")}` : "—";

  const monthLabel = new Intl.DateTimeFormat(
    locale === "ar" ? "ar-EG" : "en-US",
    { month: "long", year: "numeric" },
  ).format(new Date());

  const hasPayroll = (data.payroll?.covers ?? 0) > 0 || (data.payroll?.net ?? 0) > 0;

  return (
    <div className="space-y-6">
      {/* Greeting + date */}
      <header>
        <h1 className="text-headline-md font-bold">
          {t("welcome_greeting")}، {firstName}
        </h1>
        <p className="text-label-md text-muted-foreground">{today}</p>
      </header>

      {/* Today's attendance */}
      <section className="space-y-3">
        <SectionLabel>{t("attendance_today")}</SectionLabel>
        <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
          <CardLink href="/dashboard/status-employees?status=present">
            <StatCard
              icon={CheckCircle2}
              label={t("present_today")}
              value={data.present}
              hint={pct(data.present)}
              tone="success"
            />
          </CardLink>
          <CardLink href="/dashboard/status-employees?status=absent">
            <StatCard
              icon={XCircle}
              label={t("absent_today")}
              value={data.absent}
              hint={pct(data.absent)}
              tone="destructive"
            />
          </CardLink>
          <CardLink href="/dashboard/status-employees?status=late">
            <StatCard
              icon={Clock}
              label={t("late_today")}
              value={data.late}
              hint={pct(data.late)}
              tone="warning"
            />
          </CardLink>
          <CardLink href="/dashboard/status-employees?status=on_leave">
            <StatCard
              icon={CalendarOff}
              label={t("on_leave_today")}
              value={data.on_leave}
              hint={pct(data.on_leave)}
            />
          </CardLink>
        </div>
      </section>

      {/* Needs attention — pending-approval queue */}
      <section className="space-y-3">
        <SectionLabel>{t("needs_attention")}</SectionLabel>
        <NeedsAttention data={data} />
      </section>

      {/* Financials */}
      {hasPayroll && (
        <section className="space-y-3">
          <SectionLabel trailing={monthLabel}>{t("financials")}</SectionLabel>
          <CardLink href="/payroll">
            <PayrollSummary data={data.payroll} />
          </CardLink>
        </section>
      )}

      {/* Branch performance */}
      {data.branch_comparison.length > 0 && (
        <section className="space-y-3">
          <SectionLabel>{t("branch_performance")}</SectionLabel>
          <BranchPerformanceList branches={data.branch_comparison} />
        </section>
      )}
    </div>
  );
}

/** Makes a card navigate on click with a subtle hover affordance. */
function CardLink({
  href,
  children,
}: {
  href: string;
  children: React.ReactNode;
}) {
  return (
    <Link
      href={href}
      className="block rounded-2xl transition-shadow hover:shadow-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand"
    >
      {children}
    </Link>
  );
}

function SectionLabel({
  children,
  trailing,
}: {
  children: React.ReactNode;
  trailing?: string;
}) {
  return (
    <div className="flex items-baseline gap-2">
      <h2 className="text-label-lg font-semibold uppercase tracking-wide text-muted-foreground">
        {children}
      </h2>
      {trailing && (
        <span className="text-label-sm text-muted-foreground">· {trailing}</span>
      )}
    </div>
  );
}

type Overview = NonNullable<ReturnType<typeof useDashboardOverview>["data"]>;

function NeedsAttention({ data }: { data: Overview }) {
  const { t } = useT();
  const items = (
    [
    {
      count: data.pending_leaves,
      label: t("pending_leaves"),
      hint: t("awaiting_action"),
      icon: Hourglass,
      tone: "warning",
      href: "/leaves",
    },
    {
      count: data.pending_breaks,
      label: t("pending_breaks"),
      hint: t("awaiting_action"),
      icon: Coffee,
      tone: "warning",
      href: "/breaks",
    },
    {
      count: data.pending_loans,
      label: t("pending_loans"),
      hint: t("awaiting_action"),
      icon: Wallet,
      tone: "default",
      href: "/loans",
    },
    {
      count: data.assets_to_return,
      label: t("assets_to_return"),
      hint: t("awaiting_action"),
      icon: PackageOpen,
      tone: "destructive",
      href: "/settings/assets",
    },
    {
      count: data.expiring_compliance,
      label: t("expiring_compliance"),
      hint: t("expiring_soon"),
      icon: FileWarning,
      tone: "destructive",
      href: "/dashboard/expiring-compliance",
    },
    ] as const
  ).filter((i) => i.count > 0);

  if (items.length === 0) {
    return (
      <div className="card-flat flex items-center gap-3">
        <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-success/15 text-success">
          <CheckCheck className="h-5 w-5" />
        </div>
        <div>
          <p className="text-title-md font-semibold">{t("all_clear")}</p>
          <p className="text-label-sm text-muted-foreground">
            {t("all_clear_hint")}
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
      {items.map((i) => (
        <CardLink key={i.label} href={i.href}>
          <div className="group relative">
            <StatCard
              icon={i.icon}
              label={i.label}
              value={i.count}
              hint={i.hint}
              tone={i.tone}
            />
            <ChevronLeft className="absolute end-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground opacity-0 transition-opacity group-hover:opacity-100" />
          </div>
        </CardLink>
      ))}
    </div>
  );
}
