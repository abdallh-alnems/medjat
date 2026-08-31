"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  LayoutDashboard,
  Users,
  CalendarCheck,
  Wallet,
  LifeBuoy,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { useT } from "@/lib/i18n/use-t";
import { usePermissions } from "@/lib/hooks/use-permissions";
import type { PermissionCode } from "@/lib/permissions/model";
import type { TKey } from "@/lib/i18n/ar";

const ITEMS: {
  href: string;
  labelKey: TKey;
  icon: React.ElementType;
  permission?: PermissionCode;
}[] = [
  { href: "/dashboard", labelKey: "nav_dashboard", icon: LayoutDashboard },
  {
    href: "/employees",
    labelKey: "nav_employees",
    icon: Users,
    permission: "manage_employees",
  },
  {
    href: "/attendance",
    labelKey: "nav_attendance",
    icon: CalendarCheck,
    permission: "manage_attendance",
  },
  {
    href: "/payroll",
    labelKey: "nav_payroll",
    icon: Wallet,
    permission: "manage_payroll",
  },
  { href: "/support", labelKey: "nav_support", icon: LifeBuoy },
];

export function MobileBottomNav() {
  const pathname = usePathname();
  const { t } = useT();
  const { can } = usePermissions();
  const visible = ITEMS.filter((i) => !i.permission || can(i.permission));
  return (
    <nav className="fixed inset-x-0 bottom-0 z-30 flex h-16 items-center justify-around border-t bg-background md:hidden">
      {visible.map(({ href, labelKey, icon: Icon }) => {
        const active =
          pathname === href || pathname.startsWith(`${href}/`);
        return (
          <Link
            key={href}
            href={href}
            className={cn(
              "flex flex-1 flex-col items-center gap-1 py-1 text-label-sm",
              active ? "text-brand" : "text-muted-foreground",
            )}
          >
            <Icon className="h-5 w-5" />
            <span>{t(labelKey)}</span>
          </Link>
        );
      })}
    </nav>
  );
}
