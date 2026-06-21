import * as XLSX from "xlsx";
import type { ReportData } from "@/lib/types";
import { slug } from "./helpers";

/** Export a tabular report (or rows) to Excel. */
export function exportReportToExcel(
  report: ReportData,
  filename?: string,
) {
  const aoa: (string | number)[][] = [report.columns, ...report.rows];
  const ws = XLSX.utils.aoa_to_sheet(aoa);
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, "Sheet1");
  XLSX.writeFile(wb, filename ?? `${slug(report.title)}.xlsx`);
}

/** Export a list of objects (e.g. employees) to Excel. */
export function exportObjectsToExcel<T extends Record<string, unknown>>(
  rows: T[],
  sheetName = "Sheet1",
  filename?: string,
) {
  const ws = XLSX.utils.json_to_sheet(rows);
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, sheetName);
  XLSX.writeFile(wb, filename ?? `${slug(sheetName)}.xlsx`);
}
