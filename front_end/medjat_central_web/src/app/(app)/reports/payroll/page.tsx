"use client";

import { GenericReportPage } from "@/components/report/generic-report-page";
import { getPayrollReport } from "@/lib/api/reports";

export default function PayrollReportPage() {
  return (
    <GenericReportPage
      titleKey="payroll_report"
      fetcher={(p) => getPayrollReport({ from: p.from, to: p.to })}
    />
  );
}
