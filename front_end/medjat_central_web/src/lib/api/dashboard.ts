import { apiGet } from "./client";
import type {
  DashboardOverview,
  LiveAttendance,
} from "@/lib/types";

export function getDashboardOverview() {
  return apiGet<DashboardOverview>("app/dashboard/overview.php");
}

export function getLiveAttendance() {
  return apiGet<LiveAttendance[]>("app/dashboard/live_attendance.php");
}
