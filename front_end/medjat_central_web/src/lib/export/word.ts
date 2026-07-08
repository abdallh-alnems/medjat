import type { ReportData } from "@/lib/types";
import { slug, triggerDownload } from "./helpers";

const esc = (v: string | number) =>
  String(v ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");

/**
 * Export a tabular report as a Word (.doc) file. Uses Word's HTML support so
 * no external dependency is needed — Word opens the HTML and renders the table.
 */
export function exportReportToWord(
  report: ReportData,
  opts: { locale?: "ar" | "en" } = {},
) {
  const dir = opts.locale === "en" ? "ltr" : "rtl";
  const align = dir === "rtl" ? "right" : "left";

  const head =
    "<tr>" + report.columns.map((c) => `<th>${esc(c)}</th>`).join("") + "</tr>";
  const body = report.rows
    .map((r) => "<tr>" + r.map((c) => `<td>${esc(c)}</td>`).join("") + "</tr>")
    .join("");

  const html = `<!DOCTYPE html>
<html dir="${dir}"><head><meta charset="utf-8" />
<style>
  body { font-family: Arial, sans-serif; }
  table { border-collapse: collapse; width: 100%; }
  th, td { border: 1px solid #999; padding: 6px 8px; text-align: ${align}; }
  th { background: #f0f0f0; }
  h1 { font-size: 18px; margin: 0 0 4px; }
  p { color: #555; margin: 0 0 12px; }
</style></head>
<body>
  <h1>${esc(report.title)}</h1>
  <p>${esc(report.period)}</p>
  <table><thead>${head}</thead><tbody>${body}</tbody></table>
</body></html>`;

  const blob = new Blob(["﻿" + html], {
    type: "application/msword;charset=utf-8;",
  });
  triggerDownload(blob, `${slug(report.title)}.doc`);
}
