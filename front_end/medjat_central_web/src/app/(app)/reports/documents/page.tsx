"use client";

import { useT } from "@/lib/i18n/use-t";
import {
  useDocumentStats,
  useExpiringSoon,
  useExpiredDocs,
  useMissingDocs,
} from "@/lib/hooks/use-reports";
import {
  LoadingState,
  ErrorState,
  EmptyState,
} from "@/components/ui/states";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { FileText } from "lucide-react";

export default function DocumentsReportPage() {
  const { t } = useT();
  const stats = useDocumentStats();
  const expiring = useExpiringSoon();
  const expired = useExpiredDocs();
  const missing = useMissingDocs();

  if (stats.isLoading) return <LoadingState />;
  if (stats.isError) return <ErrorState onRetry={() => stats.refetch()} />;

  const cards = [
    { label: t("total"), value: stats.data?.total ?? 0 },
    { label: t("verified"), value: stats.data?.verified ?? 0 },
    { label: t("pending"), value: stats.data?.pending ?? 0 },
    { label: t("rejected"), value: stats.data?.rejected ?? 0 },
    { label: t("expires_soon"), value: stats.data?.expiring_soon ?? 0 },
    { label: t("expired"), value: stats.data?.expired ?? 0 },
    { label: t("missing_documents"), value: stats.data?.missing ?? 0 },
  ];

  return (
    <div className="space-y-4">
      <h1 className="text-headline-md font-bold">{t("documents_report")}</h1>

      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4 lg:grid-cols-7">
        {cards.map((c) => (
          <Card key={c.label}>
            <CardContent className="p-4">
              <p className="text-xs text-muted-foreground">{c.label}</p>
              <p className="text-headline-md font-bold">{c.value}</p>
            </CardContent>
          </Card>
        ))}
      </div>

      <ComplianceTable title={t("expires_soon")} rows={expiring.data ?? []} loading={expiring.isLoading} />
      <ComplianceTable title={t("expired")} rows={expired.data ?? []} loading={expired.isLoading} />
      <ComplianceTable title={t("missing_documents")} rows={missing.data ?? []} loading={missing.isLoading} />
    </div>
  );
}

function ComplianceTable({
  title,
  rows,
  loading,
}: {
  title: string;
  rows: { id: number; employee_name: string; type: string; status: string; expiry?: string | null }[];
  loading: boolean;
}) {
  const { t } = useT();
  if (loading) return <LoadingState />;
  if (rows.length === 0)
    return <EmptyState message={t("no_report_data")} icon={FileText} />;
  return (
    <div className="rounded-lg border">
      <div className="border-b p-3 text-body-md font-medium">{title}</div>
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>{t("name")}</TableHead>
            <TableHead>{t("document_type")}</TableHead>
            <TableHead>{t("status")}</TableHead>
            <TableHead>{t("expiry")}</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {rows.map((r, i) => (
            <TableRow key={i}>
              <TableCell className="font-medium">{r.employee_name}</TableCell>
              <TableCell>{r.type}</TableCell>
              <TableCell>
                <Badge variant="outline">{t(r.status as never)}</Badge>
              </TableCell>
              <TableCell>{r.expiry ?? "—"}</TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  );
}
