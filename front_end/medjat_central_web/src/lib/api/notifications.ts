import { apiGet, apiPost } from "./client";
import type { Notification, NotificationPrefs } from "@/lib/types";

export function listNotifications() {
  return apiGet<Notification[]>("app/notifications/list.php");
}

export function markNotificationRead(id: number) {
  return apiPost<{ status?: string }>("app/notifications/read.php", { id });
}

export function getNotificationPrefs() {
  return apiGet<NotificationPrefs>("app/auth/notification_prefs.php");
}

export function updateNotificationPrefs(data: Partial<NotificationPrefs>) {
  return apiPost<NotificationPrefs>("app/auth/notification_prefs.php", data);
}
