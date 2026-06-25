"use client";

import { Topbar } from "./topbar";
import { SidebarNav } from "./sidebar-nav";
import { MobileBottomNav } from "./mobile-bottom-nav";
import { NavigationProgress } from "./navigation-progress";

/** Authenticated, tenant-scoped shell: sidebar (desktop) + topbar + bottom nav (mobile). */
export function AppShell({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex min-h-screen">
      <NavigationProgress />
      <aside className="hidden w-64 shrink-0 border-e bg-sidebar md:block">
        <SidebarNav />
      </aside>
      <div className="flex min-w-0 flex-1 flex-col">
        <Topbar />
        <main className="flex-1 overflow-x-hidden px-4 pb-20 pt-5 md:px-6 md:pb-8 lg:px-8">
          <div className="mx-auto w-full max-w-6xl">{children}</div>
        </main>
      </div>
      <MobileBottomNav />
    </div>
  );
}
