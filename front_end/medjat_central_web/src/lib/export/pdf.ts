import jsPDF from "jspdf";
import autoTable from "jspdf-autotable";
import type { ReportData } from "@/lib/types";

/** Export a titled tabular report to PDF. RTL aware (Arabic title). */
export function exportReportToPDF(
  report: ReportData,
  opts: { locale?: "ar" | "en"; filename?: string } = {},
) {
  const { locale = "ar", filename } = opts;
  const doc = new jsPDF({ orientation: "landscape" });
  doc.text(report.title, 14, 16);
  doc.setFontSize(10);
  doc.setTextColor(120);
  doc.text(report.period, 14, 22);

  autoTable(doc, {
    head: [report.columns],
    body: report.rows.map((r) => r.map((c) => String(c))),
    startY: 28,
    styles: { halign: locale === "ar" ? "right" : "left", fontSize: 9 },
    headStyles: { fillColor: [37, 99, 235] },
  });

  doc.save(filename ?? `${slug(report.title)}.pdf`);
}

/** Export an arbitrary key→value list (e.g. a payslip) as PDF. */
export function exportKeyValuePDF(
  title: string,
  rows: [string, string | number][],
  filename?: string,
) {
  const doc = new jsPDF();
  doc.text(title, 14, 18);
  autoTable(doc, {
    body: rows.map(([k, v]) => [k, String(v)]),
    startY: 24,
    styles: { fontSize: 10 },
    columnStyles: { 0: { fontStyle: "bold", cellWidth: 80 } },
  });
  doc.save(filename ?? `${slug(title)}.pdf`);
}

function slug(s: string): string {
  return s.replace(/\s+/g, "-").toLowerCase();
}
