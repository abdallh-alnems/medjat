"use client";

import { ar, type Dictionary, type TKey } from "./ar";
import { en } from "./en";
import { useUIStore } from "@/lib/stores/ui-store";

const DICTS: Record<string, Dictionary> = { ar, en };

/** Translation hook bound to the persisted UI locale. */
export function useT() {
  const locale = useUIStore((s) => s.locale);
  const dict = DICTS[locale] ?? ar;
  return {
    t: (key: TKey): string => dict[key] ?? ar[key] ?? key,
    locale,
    dir: locale === "ar" ? "rtl" : "ltr",
  };
}

/** Server-safe lookup (defaults to Arabic). */
export function t(locale: "ar" | "en", key: TKey): string {
  const dict = DICTS[locale] ?? ar;
  return dict[key] ?? ar[key] ?? key;
}
