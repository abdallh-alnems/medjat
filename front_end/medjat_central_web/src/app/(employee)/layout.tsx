import type { Metadata } from "next";
import { LocaleToggle } from "@/features/employee-attendance/locale-toggle";

/**
 * Employee attendance surface.
 *
 * Isolated from the `(app)` administrator tree on purpose: this route group
 * imports nothing from it, and its session is a separate httpOnly cookie handled
 * entirely in `/api/employee/*`. The two areas share an origin — an accepted
 * trade recorded in the feature's plan — so keeping them from sharing *code* is
 * what keeps the blast radius small.
 *
 * Fonts, RTL, theming and the i18n provider all come from the root layout, so
 * there is nothing to re-declare here.
 */

export const metadata: Metadata = {
  title: "تسجيل الحضور | Medjat",
  description: "سجّل حضورك وانصرافك من المتصفح.",
  robots: { index: false, follow: false },
};

export default function EmployeeLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex min-h-dvh items-center justify-center bg-muted/30 p-4">
      <div className="w-full max-w-sm space-y-3">
        {children}
        {/* Below the card and on every screen, including sign-in: an employee
            who cannot read the interface has no way to reach a settings page,
            so the switch has to be wherever they are already stuck. */}
        <div className="flex justify-center">
          <LocaleToggle />
        </div>
      </div>
    </div>
  );
}
