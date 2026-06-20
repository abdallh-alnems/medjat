"use client";

import Link from "next/link";
import { useT } from "@/lib/i18n/use-t";
import {
  useBulkAdjustments,
  useDeleteBulkAdjustment,
} from "@/lib/hooks/use-bulk-adjustments";
import {
  LoadingState,
  ErrorState,
  EmptyState,
} from "@/components/ui/states";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Plus } from "lucide-react";

export default function BulkAdjustmentsPage() {
  const { t } = useT();
  const { data, isLoading, isError, refetch } = useBulkAdjustments();
  const remove = useDeleteBulkAdjustment();
  const rows = Array.isArray(data) ? data : [];

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between gap-2">
        <h1 className="text-headline-md font-bold">{t("bulk_adjustments")}</h1>
        <Button render={<Link href="/payroll/bulk-adjustments/new" />}>
          <Plus className="h-4 w-4" />
          {t("new_bulk_adjustment")}
        </Button>
      </div>

      {isLoading ? (
        <LoadingState />
      ) : isError ? (
        <ErrorState onRetry={() => refetch()} />
      ) : rows.length === 0 ? (
        <EmptyState message={t("no_records")} />
      ) : (
        <div className="rounded-lg border">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>{t("adjustment_type")}</TableHead>
                <TableHead>{t("scope")}</TableHead>
                <TableHead>{t("amount")}</TableHead>
                <TableHead>{t("month")}</TableHead>
                <TableHead>{t("actions")}</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {rows.map((b) => (
                <TableRow key={b.id}>
                  <TableCell>
                    <Badge variant={b.type === "bonus" ? "default" : "destructive"}>
                      {t(b.type)}
                    </Badge>
                  </TableCell>
                  <TableCell>{t(b.scope === "all" ? "all" : b.scope)}</TableCell>
                  <TableCell>{b.amount}</TableCell>
                  <TableCell>{b.month}</TableCell>
                  <TableCell>
                    <div className="flex gap-1">
                      <Button
                        variant="ghost"
                        size="sm"
                        render={<Link href={`/payroll/bulk-adjustments/${b.id}`} />}
                      >
                        {t("view")}
                      </Button>
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => remove.mutate(b.id)}
                      >
                        {t("delete")}
                      </Button>
                    </div>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </div>
      )}
    </div>
  );
}
