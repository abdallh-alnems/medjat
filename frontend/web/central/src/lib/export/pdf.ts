import jsPDF from "jspdf";
import autoTable from "jspdf-autotable";
import type { ReportData } from "@/lib/types";
import { slug } from "./helpers";

let arabicFontLoaded = false;

/**
 * Attempt to register an Arabic-capable font (Amiri) for jsPDF so that Arabic
 * glyphs render correctly. The font file must be served at /fonts/Amiri-Regular.ttf.
 * If loading fails (e.g. file missing), we fall back to the default font silently.
 */
async function ensureArabicFont(doc: jsPDF): Promise<void> {
  if (arabicFontLoaded) {
    doc.setFont("Amiri");
    return;
  }
  try {
    const res = await fetch("/fonts/Amiri-Regular.ttf");
    if (!res.ok) return;
    const buf = await res.arrayBuffer();
    const base64 = btoa(
      new Uint8Array(buf).reduce((s, b) => s + String.fromCharCode(b), ""),
    );
    doc.addFileToVFS("Amiri-Regular.ttf", base64);
    doc.addFont("Amiri-Regular.ttf", "Amiri", "normal");
    arabicFontLoaded = true;
    doc.setFont("Amiri");
  } catch {
    /* font unavailable — fall back to default */
  }
}

/** Export a titled tabular report to PDF. RTL aware (Arabic title). */
export async function exportReportToPDF(
  report: ReportData,
  opts: { locale?: "ar" | "en"; filename?: string } = {},
) {
  const { locale = "ar", filename } = opts;
  const doc = new jsPDF({ orientation: "landscape" });
  const pageWidth = doc.internal.pageSize.getWidth();
  const isRTL = locale === "ar";

  if (isRTL) await ensureArabicFont(doc);

  const xPos = isRTL ? pageWidth - 14 : 14;
  const align = isRTL ? "right" : "left";
  doc.text(report.title, xPos, 16, { align });
  doc.setFontSize(10);
  doc.setTextColor(120);
  doc.text(report.period, xPos, 22, { align });

  autoTable(doc, {
    head: [report.columns],
    body: report.rows.map((r) => r.map((c) => String(c))),
    startY: 28,
    styles: { halign: isRTL ? "right" : "left", fontSize: 9 },
    headStyles: { fillColor: [37, 99, 235] },
  });

  doc.save(filename ?? `${slug(report.title)}.pdf`);
}

/** Export an arbitrary key→value list (e.g. a payslip) as PDF. */
export async function exportKeyValuePDF(
  title: string,
  rows: [string, string | number][],
  filename?: string,
) {
  const doc = new jsPDF();
  await ensureArabicFont(doc);
  doc.text(title, 14, 18);
  autoTable(doc, {
    body: rows.map(([k, v]) => [k, String(v)]),
    startY: 24,
    styles: { fontSize: 10, halign: "right" },
    columnStyles: { 0: { fontStyle: "bold", cellWidth: 80 } },
  });
  doc.save(filename ?? `${slug(title)}.pdf`);
}
