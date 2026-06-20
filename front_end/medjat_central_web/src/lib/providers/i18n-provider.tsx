"use client";

import { useEffect } from "react";
import { useUIStore } from "@/lib/stores/ui-store";

/**
 * Keeps <html lang> + <html dir> in sync with the persisted UI locale (FR-031).
 * Mount once near the root.
 */
export function I18nProvider({ children }: { children: React.ReactNode }) {
  const locale = useUIStore((s) => s.locale);
  const direction = useUIStore((s) => s.direction);

  useEffect(() => {
    document.documentElement.lang = locale;
    document.documentElement.dir = direction;
  }, [locale, direction]);

  return <>{children}</>;
}
