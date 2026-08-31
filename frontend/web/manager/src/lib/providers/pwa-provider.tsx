"use client";

import { useEffect } from "react";

import { startInstallCapture } from "@/lib/pwa-install";

/**
 * Registers the shell-only service worker (`/sw.js`) for offline support.
 * No Firebase messaging SW and no push in v1 (D9).
 *
 * Also captures the browser's install prompt. That has to happen here rather
 * than on /install: the event fires once, early, on whatever page loaded first.
 */
export function PwaProvider({ children }: { children: React.ReactNode }) {
  useEffect(() => startInstallCapture(), []);

  useEffect(() => {
    if (!("serviceWorker" in navigator)) return;

    if (process.env.NODE_ENV === "production") {
      navigator.serviceWorker.register("/sw.js").catch((err) => {
        console.error("Service worker registration failed:", err);
      });
      return;
    }

    // In development the shell cache serves stale HTML that points at expired
    // dev bundles (→ blank page). Make sure no SW or cache survives here.
    navigator.serviceWorker
      .getRegistrations()
      .then((regs) => regs.forEach((r) => r.unregister()))
      .catch(() => {});
    if (typeof caches !== "undefined") {
      caches
        .keys()
        .then((keys) => keys.forEach((k) => caches.delete(k)))
        .catch(() => {});
    }
  }, []);

  return <>{children}</>;
}
