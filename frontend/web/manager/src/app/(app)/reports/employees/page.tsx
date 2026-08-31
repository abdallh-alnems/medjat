"use client";

import { GenericReportPage } from "@/components/report/generic-report-page";
import { getEmployeesReport } from "@/lib/api/reports";

export default function EmployeesReportPage() {
  return (
    <GenericReportPage
      titleKey="employees_report"
      fetcher={(p) => getEmployeesReport({ from: p.from, to: p.to })}
    />
  );
}
