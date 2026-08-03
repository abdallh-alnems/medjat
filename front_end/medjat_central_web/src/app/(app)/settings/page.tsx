"use client";

import Link from "next/link";
import { useT } from "@/lib/i18n/use-t";
import { Card, CardContent } from "@/components/ui/card";
import {
  Building2,
  Percent,
  CalendarDays,
  Banknote,
  MapPin,
  FileText,
  Tags,
  Boxes,
  Upload,
} from "lucide-react";
import type { TKey } from "@/lib/i18n/ar";

const SECTIONS: { href: string; labelKey: TKey; icon: React.ElementType }[] = [
  { href: "/settings/company", labelKey: "company_settings", icon: Building2 },
  { href: "/settings/deductions", labelKey: "deductions_settings", icon: Percent },
  { href: "/settings/leave", labelKey: "leave_settings", icon: CalendarDays },
  { href: "/settings/statutory", labelKey: "statutory_payroll", icon: Banknote },
  { href: "/settings/attendance-method", labelKey: "attendance_method_settings", icon: MapPin },
  { href: "/settings/required-documents", labelKey: "required_documents", icon: FileText },
  { href: "/settings/categories", labelKey: "categories", icon: Tags },
  { href: "/settings/assets", labelKey: "assets", icon: Boxes },
  { href: "/settings/import-punches", labelKey: "import_punches", icon: Upload },
];

export default function SettingsHub() {
  const { t } = useT();
  return (
    <div className="space-y-4">
      <h1 className="text-headline-md font-bold">{t("settings")}</h1>
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
        {SECTIONS.map((s) => {
          const Icon = s.icon;
          return (
            <Link key={s.href} href={s.href}>
              <Card className="transition-colors hover:bg-muted/40">
                <CardContent className="flex items-center gap-3 p-4">
                  <Icon className="h-6 w-6 text-primary" />
                  <span className="font-medium">{t(s.labelKey)}</span>
                </CardContent>
              </Card>
            </Link>
          );
        })}
      </div>
    </div>
  );
}
