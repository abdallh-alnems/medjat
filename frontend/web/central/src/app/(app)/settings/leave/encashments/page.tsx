"use client";

import { useT } from "@/lib/i18n/use-t";
import { listEncashments } from "@/lib/api/leaves";
import { useQuery } from "@tanstack/react-query";
import { LoadingState, ErrorState, EmptyState } from "@/components/ui/states";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";

export default function EncashmentsPage() {
  const { t, locale } = useT();
  const { data, isLoading, isError, refetch } = useQuery({
    queryKey: ["settings", "encashments"],
    queryFn: listEncashments,
  });
  const rows = Array.isArray(data) ? data : [];

  return (
    <div className="space-y-4">
      <h1 className="text-headline-md font-bold">{t("encashment")}</h1>
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
                <TableHead>{t("employee")}</TableHead>
                <TableHead>{t("amount")}</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {rows.map((r, i) => (
                <TableRow key={i}>
                  <TableCell>
                    {r.employee_name ?? `${t("employee")} #${r.employee_id}`}
                  </TableCell>
                  <TableCell>
                    {new Intl.NumberFormat(locale === "ar" ? "ar-EG" : "en-GB").format(
                      r.amount,
                    )}
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
