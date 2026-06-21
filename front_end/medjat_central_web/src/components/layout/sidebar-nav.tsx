"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  LayoutDashboard,
  Users,
  CalendarCheck,
  Wallet,
  Banknote,
  CalendarDays,
  Coffee,
  Building2,
  Clock,
  CalendarRange,
  FileBarChart,
  Settings,
  UsersRound,
  LifeBuoy,
  Bell,
  ScrollText,
  UserCircle,
  UserX,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { useT } from "@/lib/i18n/use-t";
import { Can } from "@/components/permissions/can";
import type { PermissionCode } from "@/lib/permissions/model";
import type { TKey } from "@/lib/i18n/ar";

interface NavItem {
  href: string;
  labelKey: TKey;
  icon: React.ElementType;
  permission?: PermissionCode;
}

const NAV: NavItem[] = [
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
  {
    href: "/loans",
    labelKey: "nav_loans",
    icon: Banknote,
    permission: "manage_payroll",
  },
  {
    href: "/leaves",
    labelKey: "nav_leaves",
    icon: CalendarDays,
    permission: "manage_leaves",
  },
  {
    href: "/breaks",
    labelKey: "nav_breaks",
    icon: Coffee,
    permission: "manage_leaves",
  },
  {
    href: "/branches",
    labelKey: "nav_branches",
    icon: Building2,
    permission: "manage_company_settings",
  },
  {
    href: "/shifts",
    labelKey: "nav_shifts",
    icon: Clock,
    permission: "manage_company_settings",
  },
  {
    href: "/shifts/schedule",
    labelKey: "nav_schedule",
    icon: CalendarRange,
    permission: "manage_company_settings",
  },
  {
    href: "/reports",
    labelKey: "nav_reports",
    icon: FileBarChart,
    permission: "view_reports",
  },
  {
    href: "/settings",
    labelKey: "nav_settings",
    icon: Settings,
    permission: "manage_company_settings",
  },
  {
    href: "/team",
    labelKey: "nav_team",
    icon: UsersRound,
    permission: "add_managers",
  },
  { href: "/support", labelKey: "nav_support", icon: LifeBuoy },
  { href: "/notifications", labelKey: "nav_notifications", icon: Bell },
  {
    href: "/activity-log",
    labelKey: "nav_activity_log",
    icon: ScrollText,
    permission: "view_reports",
  },
  { href: "/account", labelKey: "nav_account", icon: UserCircle },
  {
    href: "/terminated",
    labelKey: "nav_terminated",
    icon: UserX,
    permission: "manage_employees",
  },
];

export function SidebarNav() {
  const pathname = usePathname();
  const { t } = useT();

  return (
    <nav className="flex h-full flex-col gap-1 overflow-y-auto p-3">
      {NAV.map((item) => {
        const Icon = item.icon;
        const exactMatch = NAV.some((n) => n.href === pathname);
        const active = exactMatch
          ? pathname === item.href
          : pathname === item.href || pathname.startsWith(`${item.href}/`);
        const link = (
          <Link
            key={item.href}
            href={item.href}
            className={cn(
              "flex items-center gap-3 rounded-lg px-3 py-2 text-body-md transition-colors",
              active
                ? "bg-sidebar-accent font-semibold text-sidebar-accent-foreground"
                : "text-sidebar-foreground hover:bg-sidebar-accent/60",
            )}
          >
            <Icon className="h-5 w-5 shrink-0" />
            <span className="truncate">{t(item.labelKey)}</span>
          </Link>
        );
        return item.permission ? (
          <Can key={item.href} permission={item.permission}>
            {link}
          </Can>
        ) : (
          link
        );
      })}
    </nav>
  );
}
