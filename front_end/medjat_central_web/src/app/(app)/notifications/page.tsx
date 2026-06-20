"use client";

import { useT } from "@/lib/i18n/use-t";
import {
  useNotifications,
  useNotificationPrefs,
  useMarkNotificationRead,
  useUpdateNotificationPrefs,
} from "@/lib/hooks/use-notifications";
import {
  LoadingState,
  ErrorState,
  EmptyState,
} from "@/components/ui/states";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Checkbox } from "@/components/ui/checkbox";
import { Bell } from "lucide-react";

export default function NotificationsPage() {
  const { t, locale } = useT();
  const { data, isLoading, isError, refetch } = useNotifications();
  const prefs = useNotificationPrefs();
  const markRead = useMarkNotificationRead();
  const updatePrefs = useUpdateNotificationPrefs();
  const items = Array.isArray(data) ? data : [];

  const fmtDate = (s: string) =>
    new Intl.DateTimeFormat(locale === "ar" ? "ar-EG" : "en-GB").format(
      new Date(s),
    );

  return (
    <div className="space-y-4">
      <h1 className="text-headline-md font-bold">{t("notifications")}</h1>

      <Card>
        <CardContent className="space-y-3 p-4">
          <p className="font-medium">{t("notification_prefs")}</p>
          {(["email", "in_app"] as const).map((key) => (
            <label key={key} className="flex items-center gap-2 text-body-md">
              <Checkbox
                checked={Boolean(prefs.data?.[key])}
                onCheckedChange={(v) =>
                  updatePrefs.mutate({ [key]: Boolean(v) })
                }
              />
              {key === "email" ? t("email") : t("notifications")}
            </label>
          ))}
        </CardContent>
      </Card>

      {isLoading ? (
        <LoadingState />
      ) : isError ? (
        <ErrorState onRetry={() => refetch()} />
      ) : items.length === 0 ? (
        <EmptyState message={t("no_notifications")} icon={Bell} />
      ) : (
        <div className="space-y-2">
          {items.map((n) => (
            <div
              key={n.id}
              className="flex items-start justify-between rounded-lg border p-3"
            >
              <div className="min-w-0">
                <div className="flex items-center gap-2">
                  <p className="font-medium">{n.title}</p>
                  {!n.read && <Badge variant="secondary">{t("pending")}</Badge>}
                </div>
                <p className="text-body-md text-muted-foreground">{n.body}</p>
                <p className="text-xs text-muted-foreground">{fmtDate(n.created_at)}</p>
              </div>
              {!n.read && (
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => markRead.mutate(n.id)}
                >
                  {t("mark_read")}
                </Button>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
