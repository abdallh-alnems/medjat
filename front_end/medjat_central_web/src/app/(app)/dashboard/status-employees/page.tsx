"use client";

import { useSearchParams } from "next/navigation";
import Link from "next/link";
import { useLiveAttendance } from "@/lib/hooks/use-dashboard";
import { useT } from "@/lib/i18n/use-t";
import {
  LoadingState,
  ErrorState,
  EmptyState,
} from "@/components/ui/states";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { ArrowLeft } from "lucide-react";

const STATUS_KEYS: Record<string, "present" | "absent" | "late" | "leave"> = {
  present: "present",
  absent: "absent",
  late: "late",
  leave: "leave",
  on_leave: "leave",
};

const STATUS_LABEL: Record<string, "present_today" | "absent_today" | "late_today" | "on_leave_today"> = {
  present: "present_today",
  absent: "absent_today",
  late: "late_today",
  leave: "on_leave_today",
  on_leave: "on_leave_today",
};

export default function StatusEmployeesPage() {
  const sp = useSearchParams();
  const status = sp.get("status") ?? "present";
  const { t } = useT();
  const { data, isLoading, isError, refetch } = useLiveAttendance();

  const filterStatus = STATUS_KEYS[status] ?? "present";
  const rows = (data ?? []).filter((r) => r.status === filterStatus);
  const titleKey = STATUS_LABEL[status] ?? "present_today";

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-2">
        <Link href="/dashboard" className="text-brand hover:underline">
          <ArrowLeft className="h-4 w-4" />
        </Link>
        <h1 className="text-headline-md font-bold">{t("status_employees")}</h1>
      </div>
      <Card>
        <CardHeader>
          <CardTitle className="text-title-lg">{t(titleKey)}</CardTitle>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <LoadingState />
          ) : isError ? (
            <ErrorState onRetry={() => refetch()} />
          ) : rows.length === 0 ? (
            <EmptyState message={t("no_employees")} />
          ) : (
            <ul className="divide-y">
              {rows.map((r) => (
                <li key={r.employee_id} className="flex items-center justify-between py-2">
                  <Link
                    href={`/employees/${r.employee_id}`}
                    className="font-medium hover:underline"
                  >
                    {r.employee_name}
                  </Link>
                  <span className="text-label-md text-muted-foreground">
                    {r.check_in ?? "—"}
                  </span>
                </li>
              ))}
            </ul>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
