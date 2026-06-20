"use client";

import { GenericReportPage } from "@/components/report/generic-report-page";
import { getLeavesReport } from "@/lib/api/reports";

export default function LeavesReportPage() {
  return (
    <GenericReportPage
      titleKey="leaves_report"
      fetcher={(p) => getLeavesReport({ from: p.from, to: p.to })}
    />
  );
}
