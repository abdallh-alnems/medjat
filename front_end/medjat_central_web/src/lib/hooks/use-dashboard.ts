"use client";

import { useQuery } from "@tanstack/react-query";
import {
  getDashboardOverview,
  getLiveAttendance,
} from "@/lib/api/dashboard";

export function useDashboardOverview() {
  return useQuery({
    queryKey: ["dashboard", "overview"],
    queryFn: getDashboardOverview,
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
