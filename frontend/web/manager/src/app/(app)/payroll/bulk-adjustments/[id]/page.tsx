"use client";

import { use } from "react";
import { useT } from "@/lib/i18n/use-t";
import {
  useBulkAdjustment,
  useRemoveBulkMember,
} from "@/lib/hooks/use-bulk-adjustments";
import {
  LoadingState,
  ErrorState,
  EmptyState,
} from "@/components/ui/states";
import { Button } from "@/components/ui/button";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";

export default function BulkAdjustmentDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = use(params);
  const numId = Number(id);
  const { t } = useT();
  const { data, isLoading, isError, refetch } = useBulkAdjustment(numId);
  const remove = useRemoveBulkMember();

  if (isLoading) return <LoadingState />;
  if (isError) return <ErrorState onRetry={() => refetch()} />;
  if (!data) return <EmptyState />;

  return (
    <div className="space-y-4">
      <h1 className="text-headline-md font-bold">{t("bulk_adjustment_details")}</h1>

      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        <Field label={t("adjustment_type")} value={t(data.type)} />
        <Field label={t("scope")} value={t(data.scope === "all" ? "all" : data.scope)} />
        <Field label={t("amount")} value={String(data.amount)} />
        <Field label={t("month")} value={data.month} />
      </div>

      <div className="rounded-lg border">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>{t("employee")}</TableHead>
              <TableHead>{t("actions")}</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {data.members.map((eid) => (
              <TableRow key={eid}>
                <TableCell>
                  {t("employee")} #{eid}
                </TableCell>
                <TableCell>
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => remove.mutate({ id: data.id, employeeId: eid })}
                  >
                    {t("remove_member")}
                  </Button>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </div>
    </div>
  );
}

function Field({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <p className="text-xs text-muted-foreground">{label}</p>
      <p className="font-medium">{value}</p>
    </div>
  );
}
