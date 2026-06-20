"use client";

import Link from "next/link";
import { useExpiringCompliance } from "@/lib/hooks/use-employees";
import { useT } from "@/lib/i18n/use-t";
import { useUIStore } from "@/lib/stores/ui-store";
import { formatDate } from "@/lib/utils";
import {
  LoadingState,
  ErrorState,
  EmptyState,
} from "@/components/ui/states";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { ArrowRight, FileWarning } from "lucide-react";

export default function ExpiringCompliancePage() {
  const { t } = useT();
  const locale = useUIStore((s) => s.locale);
  const { data, isLoading, isError, refetch } = useExpiringCompliance();

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-2">
        <Link href="/dashboard" className="text-brand hover:underline">
          <ArrowRight className="h-4 w-4" />
        </Link>
        <h1 className="text-headline-md font-bold">{t("expiring_compliance")}</h1>
      </div>
      <Card>
        <CardHeader>
          <CardTitle className="text-title-lg">{t("documents")}</CardTitle>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <LoadingState />
          ) : isError ? (
            <ErrorState onRetry={() => refetch()} />
          ) : !data || data.length === 0 ? (
            <EmptyState icon={FileWarning} message={t("no_data")} />
          ) : (
            <ul className="divide-y">
              {data.map((item) => (
                <li
                  key={`${item.employee_id}-${item.type}`}
                  className="flex items-center justify-between py-2"
                >
                  <div>
                    <Link
                      href={`/employees/${item.employee_id}`}
                      className="font-medium hover:underline"
                    >
                      {item.employee_name}
                    </Link>
                    <p className="text-label-sm text-muted-foreground">
                      {item.type}
                      {item.expiry
                        ? ` — ${formatDate(item.expiry, locale)}`
                        : ""}
                    </p>
                  </div>
                  <Badge
                    variant={
                      item.status === "expired" ? "destructive" : "secondary"
                    }
                  >
                    {item.status === "expired"
                      ? t("expired")
                      : item.status === "missing"
                        ? t("missing_documents")
                        : t("expires_soon")}
                  </Badge>
                </li>
              ))}
            </ul>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
