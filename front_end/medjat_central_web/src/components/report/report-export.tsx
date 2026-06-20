"use client";

import { Button } from "@/components/ui/button";
import { FileDown } from "lucide-react";
import { useT } from "@/lib/i18n/use-t";
import {
  exportReportToPDF,
  exportReportToExcel,
  exportReportToCSV,
} from "@/lib/export";
import type { ReportData } from "@/lib/types";

interface Props {
  report: ReportData | null | undefined;
}

/** PDF / Excel / CSV export buttons for a report. */
export function ReportExport({ report }: Props) {
  const { t, locale } = useT();
  if (!report || report.rows.length === 0) {
    return <p className="text-body-md text-muted-foreground">{t("no_records_export")}</p>;
  }
  return (
    <div className="flex gap-2">
      <Button
        variant="outline"
        size="sm"
        onClick={() => exportReportToPDF(report, { locale })}
      >
        <FileDown className="h-4 w-4" />
        {t("pdf")}
      </Button>
      <Button variant="outline" size="sm" onClick={() => exportReportToExcel(report)}>
        <FileDown className="h-4 w-4" />
        {t("excel")}
      </Button>
      <Button variant="outline" size="sm" onClick={() => exportReportToCSV(report)}>
        <FileDown className="h-4 w-4" />
        {t("csv")}
      </Button>
    </div>
  );
}
