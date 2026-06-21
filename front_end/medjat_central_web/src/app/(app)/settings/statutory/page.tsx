"use client";

import { useT } from "@/lib/i18n/use-t";
import { useStatutoryPayroll, useUpdateStatutoryPayroll } from "@/lib/hooks/use-settings";
import { SettingsForm } from "@/components/settings/settings-form";
import { LoadingState, ErrorState } from "@/components/ui/states";

export default function StatutoryPayrollPage() {
  const { t } = useT();
  const { data, isLoading, isError, refetch } = useStatutoryPayroll();
  const update = useUpdateStatutoryPayroll();

  if (isLoading) return <LoadingState />;
  if (isError) return <ErrorState onRetry={() => refetch()} />;

  return (
    <SettingsForm
      title={t("statutory_payroll")}
      initial={data as unknown as Record<string, unknown> | null}
      onSave={(v) => update.mutate(v)}
      pending={update.isPending}
      fields={[
        { key: "social_insurance_rate", label: t("social_insurance_rate"), type: "number" },
        { key: "tax_rate", label: t("tax_rate"), type: "number" },
        { key: "health_insurance_rate", label: t("health_insurance_rate"), type: "number" },
      ]}
    />
  );
}
