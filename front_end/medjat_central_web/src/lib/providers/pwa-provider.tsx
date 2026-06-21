"use client";

import { useEffect } from "react";

/**
 * Registers the shell-only service worker (`/sw.js`) for offline support.
 * No Firebase messaging SW and no push in v1 (D9).
 */
export function PwaProvider({ children }: { children: React.ReactNode }) {
  useEffect(() => {
    if ("serviceWorker" in navigator) {
      navigator.serviceWorker.register("/sw.js").catch((err) => {
        console.error("Service worker registration failed:", err);
      });
    }
  }, []);

  return <>{children}</>;
}
