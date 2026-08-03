"use client";

import { useUIStore } from "@/lib/stores/ui-store";

/**
 * Language switch for the employee surface.
 *
 * It has to be on every screen, including the sign-in ones. An employee who
 * cannot read the interface cannot navigate to a settings page to fix that —
 * the switch is only useful where they are already stuck.
 *
 * Labelled with the *target* language in its own script ("English" / "العربية")
 * rather than with a globe or a flag: a reader who cannot read the current
 * language can still recognise their own, and flags name countries, not
 * languages.
 */
export function LocaleToggle() {
  const locale = useUIStore((s) => s.locale);
  const toggleLocale = useUIStore((s) => s.toggleLocale);

  const target = locale === "ar" ? "English" : "العربية";

  return (
    <button
      type="button"
      onClick={toggleLocale}
      // The label announces the action, because the visible text is the target
      // language on its own and reads as a statement rather than a control.
      aria-label={locale === "ar" ? "Switch to English" : "التبديل إلى العربية"}
      lang={locale === "ar" ? "en" : "ar"}
      className="text-xs text-muted-foreground underline underline-offset-4 transition-colors hover:text-foreground"
    >
      {target}
    </button>
  );
}
