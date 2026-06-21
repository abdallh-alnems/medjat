"use client";

import { useT } from "@/lib/i18n/use-t";
import { useCompanySettings, useUpdateCompanySettings } from "@/lib/hooks/use-settings";
import { SettingsForm } from "@/components/settings/settings-form";
import { LoadingState, ErrorState } from "@/components/ui/states";

export default function CompanySettingsPage() {
  const { t } = useT();
  const { data, isLoading, isError, refetch } = useCompanySettings();
  const update = useUpdateCompanySettings();

  if (isLoading) return <LoadingState />;
  if (isError) return <ErrorState onRetry={() => refetch()} />;

  return (
    <SettingsForm
      title={t("company_settings")}
      initial={data as unknown as Record<string, unknown> | null}
      onSave={(v) => update.mutate(v)}
      pending={update.isPending}
      fields={[
        { key: "name", label: t("company_name") },
        { key: "phone", label: t("phone") },
        { key: "address", label: t("address") },
        { key: "radius", label: t("radius"), type: "number" },
        { key: "currency", label: t("currency") },
      ]}
    />
  );
}
