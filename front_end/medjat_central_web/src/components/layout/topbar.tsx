"use client";

import { LogOut, Menu, Moon, Sun, Languages } from "lucide-react";
import { useTheme } from "next-themes";
import { Button } from "@/components/ui/button";
import {
  Sheet,
  SheetContent,
  SheetTrigger,
} from "@/components/ui/sheet";
import { SidebarNav } from "./sidebar-nav";
import { useT } from "@/lib/i18n/use-t";
import { useUIStore } from "@/lib/stores/ui-store";
import { useAuth } from "@/lib/hooks/use-auth";
import { toast } from "sonner";

export function Topbar() {
  const { t, locale } = useT();
  const { theme, setTheme } = useTheme();
  const toggleLocale = useUIStore((s) => s.toggleLocale);
  const { logout } = useAuth();

  return (
    <header className="sticky top-0 z-30 flex h-14 items-center justify-between gap-2 border-b bg-background/95 px-4 backdrop-blur supports-[backdrop-filter]:bg-background/80">
      <div className="flex items-center gap-2">
        {/* Mobile menu */}
        <Sheet>
          <SheetTrigger
            render={
              <Button variant="ghost" size="icon" className="md:hidden" />
            }
          >
            <Menu className="h-5 w-5" />
          </SheetTrigger>
          <SheetContent side={locale === "ar" ? "right" : "left"} className="w-72 p-0">
            <SidebarNav />
          </SheetContent>
        </Sheet>
        <span className="font-bold text-foreground">{t("app_name")}</span>
      </div>

      <div className="flex items-center gap-1">
        {/* Language toggle (persisted) — FR-031 */}
        <Button
          variant="ghost"
          size="icon"
          onClick={() => toggleLocale()}
          title={t("language")}
        >
          <Languages className="h-5 w-5" />
        </Button>
        {/* Appearance toggle (persisted) — FR-031 */}
        <Button
          variant="ghost"
          size="icon"
          onClick={() => setTheme(theme === "dark" ? "light" : "dark")}
          title={t("appearance")}
        >
          <Sun className="h-5 w-5 rotate-0 scale-100 transition-all dark:-rotate-90 dark:scale-0" />
          <Moon className="absolute h-5 w-5 rotate-90 scale-0 transition-all dark:rotate-0 dark:scale-100" />
        </Button>
        <Button
          variant="ghost"
          size="icon"
          onClick={() => {
            logout();
            toast.success(t("logout"));
          }}
          title={t("logout")}
        >
          <LogOut className="h-5 w-5" />
        </Button>
      </div>
    </header>
  );
}
