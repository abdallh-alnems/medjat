"use client";

import { useSearchParams } from "next/navigation";
import { useT } from "@/lib/i18n/use-t";
import { useRequiredSubmissions } from "@/lib/hooks/use-required-documents";
import { LoadingState, ErrorState, EmptyState } from "@/components/ui/states";
import { Badge } from "@/components/ui/badge";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import type { TKey } from "@/lib/i18n/ar";

const STATUS_KEY: Record<string, TKey> = {
  pending: "pending",
  verified: "verified",
  rejected: "rejected",
  expired: "expired",
};

export default function RequiredDocSubmissionsPage() {
  const { t } = useT();
  const sp = useSearchParams();
  const id = Number(sp.get("id") ?? 0);
  const { data, isLoading, isError, refetch } = useRequiredSubmissions(
    id || null,
  );
  const rows = Array.isArray(data) ? data : [];

  return (
    <div className="space-y-4">
      <h1 className="text-headline-md font-bold">{t("required_documents")}</h1>
      {isLoading ? (
        <LoadingState />
      ) : isError ? (
        <ErrorState onRetry={() => refetch()} />
      ) : rows.length === 0 ? (
        <EmptyState />
      ) : (
        <div className="rounded-lg border">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>{t("name")}</TableHead>
                <TableHead>{t("status")}</TableHead>
                <TableHead>{t("date")}</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {rows.map((s) => (
                <TableRow key={s.id}>
                  <TableCell className="font-medium">{s.employee_name}</TableCell>
                  <TableCell>
                    <Badge variant="outline">
                      {t(STATUS_KEY[s.status] ?? "pending")}
                    </Badge>
                  </TableCell>
                  <TableCell>{s.uploaded_at}</TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </div>
      )}
    </div>
  );
}
