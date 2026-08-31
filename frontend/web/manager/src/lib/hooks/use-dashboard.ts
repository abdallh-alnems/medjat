"use client";

import { useQuery } from "@tanstack/react-query";
import {
  getDashboardOverview,
  getLiveAttendance,
} from "@/lib/api/dashboard";

export function useDashboardOverview() {
  return useQuery({
    queryKey: ["dashboard", "overview"],
    queryFn: async () => {
      const data = await getDashboardOverview();
      // The api client resolves non-2xx responses as data (so auth flows can read
      // error bodies), which means a transient 400 — e.g. the tenant header not yet
      // attached right after a refresh — would otherwise render as a malformed
      // overview and crash the page. Treat anything missing the core shape as a
      // failure so React Query retries (and the page shows a retryable error state).
      if (!data || typeof data !== "object" || !("payroll" in data)) {
        throw new Error("dashboard_unavailable");
      }
      return data;
    },
    retry: 2,
  });
}

/** Live board — polls every 25s to mirror the mobile app (D5). */
export function useLiveAttendance(enabled = true) {
  return useQuery({
    queryKey: ["dashboard", "live"],
    queryFn: getLiveAttendance,
    enabled,
    refetchInterval: 25_000,
  });
}
