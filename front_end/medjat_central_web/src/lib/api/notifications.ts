import { apiGet, apiPost, unwrapList } from "./client";
import type { Notification, NotificationPrefs } from "@/lib/types";

export async function listNotifications(): Promise<Notification[]> {
  // Backend returns `{ notifications, unread_count }`.
  const raw = await apiGet<unknown>("app/notifications/list.php");
  return unwrapList<Notification>(raw, ["notifications", "items", "data"]);
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
