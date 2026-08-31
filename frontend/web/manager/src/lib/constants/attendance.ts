import type { AttendanceStatus } from "@/lib/types";

export const ATTENDANCE_STATUS_TONE: Record<
  AttendanceStatus,
  "default" | "secondary" | "destructive" | "outline"
> = {
  present: "default",
  late: "secondary",
  leave: "outline",
  holiday: "outline",
  absent: "destructive",
  not_arrived: "outline",
};
