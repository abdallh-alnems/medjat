"use client";

import { useState } from "react";
import Link from "next/link";
import { useT } from "@/lib/i18n/use-t";
import {
  useLeaveSettings,
  useUpdateLeaveSettings,
} from "@/lib/hooks/use-settings";
import type { LeaveSettings } from "@/lib/api/settings";
import { LoadingState, ErrorState } from "@/components/ui/states";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Checkbox } from "@/components/ui/checkbox";

export default function LeaveSettingsPage() {
  const { data, isLoading, isError, refetch } = useLeaveSettings();
  if (isLoading) return <LoadingState />;
  if (isError || !data) return <ErrorState onRetry={() => refetch()} />;
  return <LeaveForm initial={data} />;
}

function LeaveForm({ initial }: { initial: LeaveSettings }) {
  const { t } = useT();
  const update = useUpdateLeaveSettings();
  const [form, setForm] = useState<LeaveSettings>(() => initial);

  const set = <K extends keyof LeaveSettings>(k: K, v: LeaveSettings[K]) =>
    setForm((f) => ({ ...f, [k]: v }));

  const numOrNull = (v: string) => (v === "" ? null : Number(v));

  return (
    <div className="mx-auto max-w-2xl space-y-4">
      <h1 className="text-headline-md font-bold">{t("leave_settings")}</h1>

      <Card>
        <CardContent className="space-y-4 p-4">
          <div className="space-y-1.5">
            <Label>{t("default_annual_leave_days")}</Label>
            <Input
              type="number"
              value={form.default_annual_leave_days ?? 0}
              onChange={(e) =>
                set("default_annual_leave_days", Number(e.target.value) || 0)
              }
            />
          </div>
          <label className="flex items-center gap-2 text-body-md">
            <Checkbox
              checked={form.auto_rollover_enabled}
              onCheckedChange={(v) => set("auto_rollover_enabled", Boolean(v))}
            />
            {t("auto_rollover")}
          </label>
          <label className="flex items-center gap-2 text-body-md">
            <Checkbox
              checked={form.apply_legal_seniority_entitlement}
              onCheckedChange={(v) =>
                set("apply_legal_seniority_entitlement", Boolean(v))
              }
            />
            {t("legal_seniority_entitlement")}
          </label>
        </CardContent>
      </Card>

      {/* ── Carryover ── */}
      <Card>
        <CardHeader>
          <CardTitle>{t("carryover")}</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <label className="flex items-center gap-2 text-body-md">
            <Checkbox
              checked={form.carryover_enabled}
              onCheckedChange={(v) => set("carryover_enabled", Boolean(v))}
            />
            {t("enable_carryover")}
          </label>

          {form.carryover_enabled && (
            <div className="space-y-4 border-s ps-3">
              <div className="space-y-1.5">
                <Label>{t("max_carryover_days")}</Label>
                <Input
                  type="number"
                  value={form.leave_carryover_max_days ?? ""}
                  onChange={(e) =>
                    set("leave_carryover_max_days", numOrNull(e.target.value))
                  }
                />
              </div>
              <div className="space-y-1.5">
                <Label>{t("carryover_expiry_months")}</Label>
                <Input
                  type="number"
                  value={form.carryover_expiry_months ?? ""}
                  onChange={(e) =>
                    set("carryover_expiry_months", numOrNull(e.target.value))
                  }
                />
              </div>
              <div className="space-y-1.5">
                <Label>{t("carryover_legal_min")}</Label>
                <Input
                  type="number"
                  value={form.carryover_legal_min_days ?? ""}
                  onChange={(e) =>
                    set("carryover_legal_min_days", numOrNull(e.target.value))
                  }
                />
              </div>
              <label className="flex items-center gap-2 text-body-md">
                <Checkbox
                  checked={form.carryover_encash_excess}
                  onCheckedChange={(v) =>
                    set("carryover_encash_excess", Boolean(v))
                  }
                />
                {t("encash_excess")}
              </label>
            </div>
          )}
        </CardContent>
      </Card>

      <div className="flex flex-wrap gap-2">
        <Button onClick={() => update.mutate(form)} disabled={update.isPending}>
          {update.isPending ? t("saving") : t("save_changes")}
        </Button>
        <Button
          variant="outline"
          render={<Link href="/settings/leave/carryover-policies" />}
        >
          {t("carryover_policy")}
        </Button>
        <Button
          variant="outline"
          render={<Link href="/settings/leave/encashments" />}
        >
          {t("encashment")}
        </Button>
      </div>
    </div>
  );
}
