"use client";

import Link from "next/link";
import { useTerminatedEmployees } from "@/lib/hooks/use-employees";
import { useToastMutation } from "@/lib/hooks/use-org";
import { reactivateEmployee } from "@/lib/api/employees";
import { useT } from "@/lib/i18n/use-t";
import { usePermissions } from "@/lib/hooks/use-permissions";
import {
  LoadingState,
  ErrorState,
  EmptyState,
} from "@/components/ui/states";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { formatDate } from "@/lib/utils";
import { useUIStore } from "@/lib/stores/ui-store";
import { Can } from "@/components/permissions/can";

export default function TerminatedPage() {
  const { t } = useT();
  const locale = useUIStore((s) => s.locale);
  const { can } = usePermissions();
  const { data, isLoading, isError, refetch } = useTerminatedEmployees();
  const reactivate = useToastMutation(
    (id: number) => reactivateEmployee(id),
    {
      successMessage: t("reactivate"),
      invalidate: [["employees", "terminated"], ["employees", "list"]],
    },
  );

  return (
    <div className="space-y-4">
      <h1 className="text-headline-md font-bold">{t("terminated_employees")}</h1>
      <Card>
        <CardContent className="py-4">
          {isLoading ? (
            <LoadingState />
          ) : isError ? (
            <ErrorState onRetry={() => refetch()} />
          ) : !data || data.length === 0 ? (
            <EmptyState message={t("no_employees")} />
          ) : (
            <ul className="divide-y">
              {data.map((emp) => (
                <li key={emp.id} className="flex items-center justify-between py-2">
                  <div>
                    <Link href={`/employees/${emp.id}`} className="font-medium hover:underline">
                      {emp.name}
                    </Link>
                    <p className="text-label-sm text-muted-foreground">
                      {t("last_working_day")}: {formatDate(emp.last_working_day, locale)}
                    </p>
                  </div>
                  <Can permission="manage_employees">
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => reactivate.mutate(emp.id)}
                      disabled={reactivate.isPending}
                    >
                      {t("reactivate")}
                    </Button>
                  </Can>
                </li>
              ))}
            </ul>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
