"use client";

import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { EmptyState } from "@/components/ui/states";
import { useT } from "@/lib/i18n/use-t";
import type { ReportData } from "@/lib/types";

interface Props {
  report: ReportData | null | undefined;
}

/** Render a ReportData payload as a table. */
export function ReportTable({ report }: Props) {
  const { t } = useT();
  if (!report || report.rows.length === 0) {
    return <EmptyState message={t("no_report_data")} />;
  }
  return (
    <div className="rounded-lg border">
      <Table>
        <TableHeader>
          <TableRow>
            {report.columns.map((c, i) => (
              <TableHead key={i}>{c}</TableHead>
            ))}
          </TableRow>
        </TableHeader>
        <TableBody>
          {report.rows.map((row, i) => (
            <TableRow key={i}>
              {row.map((cell, j) => (
                <TableCell key={j}>{cell == null ? "—" : String(cell)}</TableCell>
              ))}
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  );
}
