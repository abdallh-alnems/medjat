"use client";

import { useQuery } from "@tanstack/react-query";
import { useToastMutation } from "@/lib/hooks/use-org";
import {
  listNotifications,
  markNotificationRead,
  getNotificationPrefs,
  updateNotificationPrefs,
} from "@/lib/api/notifications";
import type { NotificationPrefs } from "@/lib/types";

const QK = ["notifications"] as const;

export function useNotifications() {
  return useQuery({
    queryKey: [...QK, "list"],
    queryFn: listNotifications,
  });
}

export function useNotificationPrefs() {
  return useQuery({
    queryKey: [...QK, "prefs"],
    queryFn: getNotificationPrefs,
  });
}

export function useMarkNotificationRead() {
  return useToastMutation(
    (id: number) => markNotificationRead(id),
    { invalidate: [QK] },
  );
}

export function useUpdateNotificationPrefs() {
  return useToastMutation(
    (data: Partial<NotificationPrefs>) => updateNotificationPrefs(data),
    { invalidate: [[...QK, "prefs"] as const] },
  );
}
