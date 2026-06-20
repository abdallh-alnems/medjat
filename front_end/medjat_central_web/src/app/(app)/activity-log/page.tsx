"use client";

import { useT } from "@/lib/i18n/use-t";
import { listAudit } from "@/lib/api/audit";
import { useQuery } from "@tanstack/react-query";
import {
  LoadingState,
  ErrorState,
  EmptyState,
} from "@/components/ui/states";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { ScrollText } from "lucide-react";

export default function ActivityLogPage() {
  const { t, locale } = useT();
  const { data, isLoading, isError, refetch } = useQuery({
    queryKey: ["audit", "list"],
    queryFn: listAudit,
  });
  const rows = Array.isArray(data) ? data : [];

  const fmtDate = (s: string) =>
    new Intl.DateTimeFormat(locale === "ar" ? "ar-EG" : "en-GB", {
      dateStyle: "medium",
      timeStyle: "short",
    }).format(new Date(s));

  return (
    <div className="space-y-4">
      <h1 className="text-headline-md font-bold">{t("activity_log")}</h1>
      {isLoading ? (
        <LoadingState />
      ) : isError ? (
        <ErrorState onRetry={() => refetch()} />
      ) : rows.length === 0 ? (
        <EmptyState message={t("no_activity")} icon={ScrollText} />
      ) : (
        <div className="rounded-lg border">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>{t("actor")}</TableHead>
                <TableHead>{t("action")}</TableHead>
                <TableHead>{t("target")}</TableHead>
                <TableHead>{t("date")}</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {rows.map((a) => (
                <TableRow key={a.id}>
                  <TableCell className="font-medium">{a.actor}</TableCell>
                  <TableCell>{a.action}</TableCell>
                  <TableCell>{a.target ?? "—"}</TableCell>
                  <TableCell>{fmtDate(a.created_at)}</TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </div>
      )}
    </div>
  );
}
