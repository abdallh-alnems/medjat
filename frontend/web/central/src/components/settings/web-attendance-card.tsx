"use client";

/**
 * The company switch for browser attendance, plus its per-category exceptions.
 *
 * The screen is deliberately blunt about what it is offering. A browser cannot
 * read the access point the device is joined to, gets no location-spoofing
 * signal, and cannot run the face model — so an administrator turning this on is
 * lowering the verification standard for whoever it covers, and should be told
 * that in the same breath as the toggle rather than discovering it after a
 * disputed punch. That is why the limitations and the unprotected branches are
 * listed here and not hidden in documentation.
 */

import { useT } from "@/lib/i18n/use-t";
import type { TKey } from "@/lib/i18n/ar";
import type {
  AttendanceMethodConfig,
  WebChannelLimitation,
} from "@/lib/api/settings";
import {
  useUpdateWebAttendanceSettings,
  useUpdateCategoryWebAccess,
} from "@/lib/hooks/use-settings";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Checkbox } from "@/components/ui/checkbox";
import { Badge } from "@/components/ui/badge";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

const LIMITATION_KEYS: Record<WebChannelLimitation, TKey> = {
  wifi_bssid: "web_limit_wifi",
  mock_location: "web_limit_mock",
  face_match: "web_limit_face",
};

/** "inherit" is a real state, not the absence of one — see update_web_access.php. */
type AccessValue = "inherit" | "allowed" | "refused";

function toAccessValue(v: boolean | null | undefined): AccessValue {
  if (v === true) return "allowed";
  if (v === false) return "refused";
  return "inherit";
}

export function WebAttendanceCard({
  config,
}: {
  config: AttendanceMethodConfig;
}) {
  const { t } = useT();
  const save = useUpdateWebAttendanceSettings();
  const saveCategory = useUpdateCategoryWebAccess();

  const enabled = config.web_attendance_enabled;
  const limitations = config.web_channel_limitations ?? [];
  const unprotected = config.branches_without_ip_networks ?? [];

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t("web_attendance")}</CardTitle>
      </CardHeader>
      <CardContent className="space-y-4 p-4 pt-0">
        <div className="flex items-start justify-between gap-4">
          <div>
            <p className="font-medium">{t("web_attendance_enable")}</p>
            <p className="text-body-md text-muted-foreground">
              {t("web_attendance_hint")}
            </p>
          </div>
          <Checkbox
            checked={enabled}
            disabled={save.isPending}
            onCheckedChange={(v) =>
              save.mutate({ web_attendance_enabled: Boolean(v) })
            }
          />
        </div>

        {enabled && (
          <>
            <div className="flex items-start justify-between gap-4 border-t pt-4">
              <div>
                <p className="font-medium">{t("web_attendance_photo")}</p>
                <p className="text-body-md text-muted-foreground">
                  {t("web_attendance_photo_hint")}
                </p>
              </div>
              <Checkbox
                checked={config.web_attendance_photo_required}
                disabled={save.isPending}
                onCheckedChange={(v) =>
                  save.mutate({ web_attendance_photo_required: Boolean(v) })
                }
              />
            </div>

            {/* Placed above the limitations, because this one is not a caveat
                about weaker verification — it means the channel does not work
                at all. An administrator who reads the list below first would
                come away thinking the feature is running. */}
            {config.web_requires_gps_only && (
              <div className="rounded-md border border-destructive/40 bg-destructive/5 p-3">
                <p className="font-medium">{t("web_needs_gps_only")}</p>
                <p className="mt-1 text-body-md text-muted-foreground">
                  {t("web_needs_gps_only_hint")}
                </p>
              </div>
            )}

            {limitations.length > 0 && (
              <div className="rounded-md border border-amber-500/40 bg-amber-500/5 p-3">
                <p className="font-medium">{t("web_limitations_title")}</p>
                <ul className="mt-1 list-disc space-y-1 pe-5 text-body-md text-muted-foreground">
                  {limitations.map((l) => (
                    <li key={l}>{t(LIMITATION_KEYS[l] ?? (l as TKey))}</li>
                  ))}
                </ul>
              </div>
            )}

            {unprotected.length > 0 && (
              <div className="rounded-md border border-amber-500/40 bg-amber-500/5 p-3">
                <p className="font-medium">{t("web_branches_no_ip")}</p>
                <p className="mt-1 text-body-md text-muted-foreground">
                  {t("web_branches_no_ip_hint")}
                </p>
                <div className="mt-2 flex flex-wrap gap-1">
                  {unprotected.map((b) => (
                    <Badge key={b.id} variant="secondary">
                      {b.name}
                    </Badge>
                  ))}
                </div>
              </div>
            )}

            <div className="rounded-md border p-3">
              <p className="font-medium">{t("web_attendance_link")}</p>
              <p className="mt-1 select-all font-mono text-body-md" dir="ltr">
                {typeof window !== "undefined"
                  ? `${window.location.origin}/me/login`
                  : "/me/login"}
              </p>
              <p className="mt-1 text-xs text-muted-foreground">
                {t("web_attendance_link_hint")}
              </p>
            </div>

            {config.categories.length > 0 && (
              <div className="border-t pt-4">
                <p className="font-medium">{t("web_category_exceptions")}</p>
                <p className="text-body-md text-muted-foreground">
                  {t("web_category_exceptions_hint")}
                </p>
                <div className="mt-3 space-y-2">
                  {config.categories.map((c) => {
                    const value = toAccessValue(c.web_attendance_allowed);
                    return (
                      <div
                        key={c.id}
                        className="flex items-center justify-between gap-3"
                      >
                        <span className="text-body-md">
                          {c.name}
                          <span className="ms-2 text-xs text-muted-foreground">
                            {c.employee_count}
                          </span>
                        </span>
                        <Select
                          value={value}
                          onValueChange={(v) =>
                            v &&
                            saveCategory.mutate({
                              id: c.id,
                              web_attendance_allowed:
                                v === "inherit" ? null : v === "allowed",
                            })
                          }
                        >
                          <SelectTrigger className="w-44">
                            <SelectValue>
                              {() => t(`web_access_${value}` as TKey)}
                            </SelectValue>
                          </SelectTrigger>
                          <SelectContent>
                            <SelectItem value="inherit">
                              {t("web_access_inherit")}
                            </SelectItem>
                            <SelectItem value="allowed">
                              {t("web_access_allowed")}
                            </SelectItem>
                            <SelectItem value="refused">
                              {t("web_access_refused")}
                            </SelectItem>
                          </SelectContent>
                        </Select>
                      </div>
                    );
                  })}
                </div>
              </div>
            )}
          </>
        )}
      </CardContent>
    </Card>
  );
}
