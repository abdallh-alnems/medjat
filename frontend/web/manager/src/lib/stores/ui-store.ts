"use client";

import { create } from "zustand";
import { persist } from "zustand/middleware";

export type Locale = "ar" | "en";
export type Direction = "rtl" | "ltr";

interface UIState {
  locale: Locale;
  direction: Direction;
  setLocale: (locale: Locale) => void;
  toggleLocale: () => void;
}

export const useUIStore = create<UIState>()(
  persist(
    (set) => ({
      locale: "ar",
      direction: "rtl",
      setLocale: (locale) =>
        set({ locale, direction: locale === "ar" ? "rtl" : "ltr" }),
      toggleLocale: () =>
        set((s) => ({
          locale: s.locale === "ar" ? "en" : "ar",
          direction: s.locale === "ar" ? "ltr" : "rtl",
        })),
    }),
    {
      name: "permedjat-ui",
    },
  ),
);
