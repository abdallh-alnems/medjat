"use client";

import Link from "next/link";
import { useT } from "@/lib/i18n/use-t";
import { Card, CardContent } from "@/components/ui/card";
import {
  CalendarCheck,
  Wallet,
  Users,
  CalendarDays,
  FileText,
} from "lucide-react";
import type { TKey } from "@/lib/i18n/ar";

const REPORTS: { href: string; labelKey: TKey; icon: React.ElementType }[] = [
  { href: "/reports/attendance", labelKey: "attendance_report", icon: CalendarCheck },
  { href: "/reports/payroll", labelKey: "payroll_report", icon: Wallet },
  { href: "/reports/employees", labelKey: "employees_report", icon: Users },
  { href: "/reports/leaves", labelKey: "leaves_report", icon: CalendarDays },
  { href: "/reports/documents", labelKey: "documents_report", icon: FileText },
];

export default function ReportsHub() {
  const { t } = useT();
  return (
    <div className="space-y-4">
      <h1 className="text-headline-md font-bold">{t("reports")}</h1>
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
        {REPORTS.map((r) => {
          const Icon = r.icon;
          return (
            <Link key={r.href} href={r.href}>
              <Card className="transition-colors hover:bg-muted/40">
                <CardContent className="flex items-center gap-3 p-4">
                  <Icon className="h-6 w-6 text-primary" />
                  <span className="font-medium">{t(r.labelKey)}</span>
                </CardContent>
              </Card>
            </Link>
          );
        })}
      </div>
    </div>
  );
}
