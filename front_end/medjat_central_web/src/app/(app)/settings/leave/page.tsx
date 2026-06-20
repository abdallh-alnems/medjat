"use client";

import Link from "next/link";
import { useT } from "@/lib/i18n/use-t";
import { useLeaveSettings, useUpdateLeaveSettings } from "@/lib/hooks/use-settings";
import { SettingsForm } from "@/components/settings/settings-form";
import { LoadingState, ErrorState } from "@/components/ui/states";
import { Button } from "@/components/ui/button";

export default function LeaveSettingsPage() {
  const { t } = useT();
  const { data, isLoading, isError, refetch } = useLeaveSettings();
  const update = useUpdateLeaveSettings();

  if (isLoading) return <LoadingState />;
  if (isError) return <ErrorState onRetry={() => refetch()} />;

  return (
    <div className="space-y-4">
      <SettingsForm
        title={t("leave_settings")}
        initial={data as unknown as Record<string, unknown> | null}
        onSave={(v) => update.mutate(v)}
        pending={update.isPending}
        fields={[
          { key: "annual_entitlement", label: t("leave_balance"), type: "number" },
          { key: "sick_entitlement", label: t("leave_balance"), type: "number" },
          { key: "max_carryover", label: t("carryover"), type: "number" },
          { key: "carryover_enabled", label: t("carryover"), type: "checkbox" },
          { key: "encashable", label: t("encashment"), type: "checkbox" },
        ]}
      />
      <div className="flex gap-2">
        <Button variant="outline" render={<Link href="/settings/leave/carryover-policies" />}>
          {t("carryover_policy")}
        </Button>
        <Button variant="outline" render={<Link href="/settings/leave/encashments" />}>
          {t("encashment")}
        </Button>
      </div>
    </div>
  );
}
