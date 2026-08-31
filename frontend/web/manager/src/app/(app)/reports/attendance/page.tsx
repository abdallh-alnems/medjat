"use client";

import { GenericReportPage } from "@/components/report/generic-report-page";
import { getAttendanceReport } from "@/lib/api/reports";

export default function AttendanceReportPage() {
  return (
    <GenericReportPage
      titleKey="attendance_report"
      fetcher={(p) => getAttendanceReport({ from: p.from, to: p.to })}
    />
  );
}
