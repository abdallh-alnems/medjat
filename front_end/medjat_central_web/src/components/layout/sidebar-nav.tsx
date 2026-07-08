"use client";

import Link from "next/link";
import Image from "next/image";
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
import { usePermissions } from "@/lib/hooks/use-permissions";
import type { PermissionCode } from "@/lib/permissions/model";
import type { TKey } from "@/lib/i18n/ar";

interface NavItem {
  href: string;
  labelKey: TKey;
  icon: React.ElementType;
  permission?: PermissionCode;
}

interface NavGroup {
  labelKey?: TKey;
  items: NavItem[];
}

const GROUPS: NavGroup[] = [
  {
    items: [
      { href: "/dashboard", labelKey: "nav_dashboard", icon: LayoutDashboard },
    ],
  },
  {
    labelKey: "nav_group_people",
    items: [
      { href: "/employees", labelKey: "nav_employees", icon: Users, permission: "manage_employees" },
      { href: "/attendance", labelKey: "nav_attendance", icon: CalendarCheck, permission: "manage_attendance" },
      { href: "/leaves", labelKey: "nav_leaves", icon: CalendarDays, permission: "manage_leaves" },
      { href: "/breaks", labelKey: "nav_breaks", icon: Coffee, permission: "manage_leaves" },
      { href: "/terminated", labelKey: "nav_terminated", icon: UserX, permission: "manage_employees" },
    ],
  },
  {
    labelKey: "nav_group_finance",
    items: [
      { href: "/payroll", labelKey: "nav_payroll", icon: Wallet, permission: "manage_payroll" },
      { href: "/loans", labelKey: "nav_loans", icon: Banknote, permission: "manage_payroll" },
    ],
  },
  {
    labelKey: "nav_group_operations",
    items: [
      { href: "/branches", labelKey: "nav_branches", icon: Building2, permission: "manage_company_settings" },
      { href: "/shifts", labelKey: "nav_shifts", icon: Clock, permission: "manage_company_settings" },
      { href: "/shifts/schedule", labelKey: "nav_schedule", icon: CalendarRange, permission: "manage_company_settings" },
    ],
  },
  {
    labelKey: "nav_group_insights",
    items: [
      { href: "/reports", labelKey: "nav_reports", icon: FileBarChart, permission: "view_reports" },
      // The audit endpoint (audit/list.php) requires manage_company_settings —
      // gating on view_reports let viewers/HR open it into a 403. Match backend.
      { href: "/activity-log", labelKey: "nav_activity_log", icon: ScrollText, permission: "manage_company_settings" },
    ],
  },
  {
    labelKey: "nav_group_admin",
    items: [
      { href: "/settings", labelKey: "nav_settings", icon: Settings, permission: "manage_company_settings" },
      { href: "/team", labelKey: "nav_team", icon: UsersRound, permission: "add_managers" },
      { href: "/support", labelKey: "nav_support", icon: LifeBuoy },
    ],
  },
  {
    labelKey: "nav_group_account",
    items: [
      { href: "/notifications", labelKey: "nav_notifications", icon: Bell },
      { href: "/account", labelKey: "nav_account", icon: UserCircle },
    ],
  },
];

/** Flat list of all hrefs, used to decide exact- vs prefix-matching for the active state. */
const ALL_HREFS = GROUPS.flatMap((g) => g.items.map((i) => i.href));

export function SidebarNav() {
  const pathname = usePathname();
  const { t } = useT();
  const { can } = usePermissions();

  const exactMatch = ALL_HREFS.some((href) => href === pathname);

  return (
    <nav className="flex h-full flex-col overflow-y-auto">
      <Link
        href="/dashboard"
        className="flex items-center gap-2.5 px-4 py-4"
      >
        <Image
          src="/logo.png"
          alt=""
          width={32}
          height={32}
          className="h-8 w-8 rounded-lg"
        />
        <span className="truncate text-body-lg font-bold text-sidebar-foreground">
          {t("app_name")}
        </span>
      </Link>

      <div className="flex flex-col gap-5 px-3 pb-4">
        {GROUPS.map((group, gi) => {
          const visible = group.items.filter((i) => !i.permission || can(i.permission));
          if (visible.length === 0) return null;

          return (
            <div key={gi} className="flex flex-col gap-0.5">
              {group.labelKey && (
                <p className="px-3 pb-1 text-label-sm font-medium uppercase tracking-wide text-text-tertiary">
                  {t(group.labelKey)}
                </p>
              )}
              {visible.map((item) => {
                const Icon = item.icon;
                const active = exactMatch
                  ? pathname === item.href
                  : pathname === item.href || pathname.startsWith(`${item.href}/`);
                return (
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
              })}
            </div>
          );
        })}
      </div>
    </nav>
  );
}
