"use client";

import { useT } from "@/lib/i18n/use-t";
import {
  useAttendanceMethodSettings,
  useUpdateAttendanceMethodSettings,
} from "@/lib/hooks/use-settings";
import { LoadingState, ErrorState } from "@/components/ui/states";
import { SettingsForm } from "@/components/settings/settings-form";
import type { AttendanceMethod } from "@/lib/types";

const METHODS: AttendanceMethod[] = ["qr_gps", "gps_only", "manual"];

export default function AttendanceMethodSettingsPage() {
  const { t } = useT();
  const { data, isLoading, isError, refetch } = useAttendanceMethodSettings();
  const update = useUpdateAttendanceMethodSettings();

  if (isLoading) return <LoadingState />;
  if (isError) return <ErrorState onRetry={() => refetch()} />;

  return (
    <SettingsForm
      title={t("attendance_method_settings")}
      initial={data as unknown as Record<string, unknown> | null}
      onSave={(v) => update.mutate(v)}
      pending={update.isPending}
      fields={[
        { key: "geofence_strict", label: t("attendance_method"), type: "checkbox" },
      ]}
    />
  );
}
