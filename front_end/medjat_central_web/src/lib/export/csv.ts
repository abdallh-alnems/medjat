import type { ReportData } from "@/lib/types";
import { slug, triggerDownload } from "./helpers";

/** Convert a tabular report to CSV text. */
export function reportToCSV(report: ReportData): string {
  const esc = (v: string | number) => {
    const s = String(v ?? "");
    return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };
  const lines = [
    report.columns.map(esc).join(","),
    ...report.rows.map((r) => r.map(esc).join(",")),
  ];
  return lines.join("\n");
}

/** Export a tabular report as a CSV file download. */
export function exportReportToCSV(report: ReportData, filename?: string) {
  const csv = reportToCSV(report);
  downloadCSV(csv, filename ?? `${slug(report.title)}.csv`);
}

/** Trigger a CSV/text download (used for the payroll bank file). */
export function downloadCSV(csv: string, filename: string) {
  const blob = new Blob(["\uFEFF" + csv], {
    type: "text/csv;charset=utf-8;",
  });
  triggerDownload(blob, filename);
}
