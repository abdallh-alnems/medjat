import { apiGet, apiPost, unwrapList } from "./client";
import type { Notification, NotificationPrefs } from "@/lib/types";

export async function listNotifications(): Promise<Notification[]> {
  // Backend returns `{ notifications, unread_count }`.
  const raw = await apiGet<unknown>("v1/notifications");
  return unwrapList<Notification>(raw, ["notifications", "items", "data"]);
}

export function markNotificationRead(id: number) {
  return apiPost<{ status?: string }>("v1/notifications/read", { id });
}

export function getNotificationPrefs() {
  return apiGet<NotificationPrefs>("v1/auth/notification-prefs");
}

export function updateNotificationPrefs(data: Partial<NotificationPrefs>) {
  return apiPost<NotificationPrefs>("v1/auth/notification-prefs", data);
}
