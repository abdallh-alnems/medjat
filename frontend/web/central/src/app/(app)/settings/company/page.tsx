"use client";

import { useState } from "react";
import { useT } from "@/lib/i18n/use-t";
import {
  useCompanySettings,
  useUpdateCompanySettings,
} from "@/lib/hooks/use-settings";
import type { CompanySettings } from "@/lib/api/settings";
import { LoadingState, ErrorState } from "@/components/ui/states";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Minus, Plus } from "lucide-react";
// Shared with the onboarding form so the two cannot offer different lists.
import {
  CURRENCIES,
  WEEKDAYS,
  supportedZones,
} from "@/lib/locale-defaults";

export default function CompanySettingsPage() {
  const { data, isLoading, isError, refetch } = useCompanySettings();

  if (isLoading) return <LoadingState />;
  if (isError || !data) return <ErrorState onRetry={() => refetch()} />;

  return <CompanyForm initial={data} />;
}

function CompanyForm({ initial }: { initial: CompanySettings }) {
  const { t } = useT();
  const update = useUpdateCompanySettings();

  const [form, setForm] = useState<Partial<CompanySettings>>(() => initial);

  const set = <K extends keyof CompanySettings>(
    key: K,
    value: CompanySettings[K],
  ) => setForm((f) => ({ ...f, [key]: value }));

  const cycleStart = form.cycle_start_day ?? 1;
  const weekStart = form.week_start_day ?? 6;
  const zones = supportedZones(form.timezone);

  const cyclePreview =
    cycleStart <= 1
      ? t("cycle_normal_month")
      : t("cycle_window_preview")
          .replace("@from", String(cycleStart))
          .replace("@to", String(cycleStart - 1));

  const onSave = () => {
    update.mutate({
      name: form.name,
      currency: form.currency,
      timezone: form.timezone,
      cycle_start_day: cycleStart,
      week_start_day: weekStart,
      commercial_register: form.commercial_register ?? "",
      company_phone: form.company_phone ?? "",
      company_address: form.company_address ?? "",
    });
  };

  return (
    <div className="mx-auto max-w-2xl space-y-4">
      <h1 className="text-headline-md font-bold">{t("company_data")}</h1>

      {/* ── Company data ── */}
      <Card>
        <CardHeader>
          <CardTitle>{t("company_data")}</CardTitle>
        </CardHeader>
        <CardContent className="space-y-1.5">
          <Label>{t("company_name")}</Label>
          <Input
            value={form.name ?? ""}
            onChange={(e) => set("name", e.target.value)}
          />
        </CardContent>
      </Card>

      {/* ── Localization ── */}
      <Card>
        <CardHeader>
          <CardTitle>{t("localization_section")}</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="space-y-1.5">
            <Label>{t("currency_label")}</Label>
            <Select
              value={form.currency ?? "EGP"}
              onValueChange={(v) => set("currency", v ?? "EGP")}
            >
              <SelectTrigger className="w-full">
                <SelectValue>{(v) => (v as string) || "EGP"}</SelectValue>
              </SelectTrigger>
              <SelectContent>
                {CURRENCIES.map((c) => (
                  <SelectItem key={c} value={c}>
                    {c}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <div className="space-y-1.5">
            <Label>{t("timezone_label")}</Label>
            <Select
              value={form.timezone ?? "Africa/Cairo"}
              onValueChange={(v) => set("timezone", v ?? "Africa/Cairo")}
            >
              <SelectTrigger className="w-full">
                <SelectValue>
                  {(v) =>
                    ((v as string) || "Africa/Cairo").replace(/_/g, " ")
                  }
                </SelectValue>
              </SelectTrigger>
              <SelectContent className="max-h-72">
                {zones.map((z) => (
                  <SelectItem key={z} value={z}>
                    {z.replace(/_/g, " ")}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
        </CardContent>
      </Card>

      {/* ── Attendance cycle ── */}
      <Card>
        <CardHeader>
          <CardTitle>{t("attendance_cycle")}</CardTitle>
        </CardHeader>
        <CardContent className="space-y-3">
          <p className="text-body-md text-muted-foreground">
            {t("cycle_start_day_hint")}
          </p>
          <div className="flex items-center gap-3">
            <span className="flex-1 font-medium">
              {t("cycle_start_day_label")}
            </span>
            <Button
              type="button"
              variant="outline"
              size="icon"
              disabled={cycleStart <= 1}
              onClick={() => set("cycle_start_day", cycleStart - 1)}
            >
              <Minus className="h-4 w-4" />
            </Button>
            <span className="w-9 text-center text-headline-sm font-bold text-primary">
              {cycleStart}
            </span>
            <Button
              type="button"
              variant="outline"
              size="icon"
              disabled={cycleStart >= 28}
              onClick={() => set("cycle_start_day", cycleStart + 1)}
            >
              <Plus className="h-4 w-4" />
            </Button>
          </div>
          <p className="text-body-md text-muted-foreground">{cyclePreview}</p>
        </CardContent>
      </Card>

      {/* ── Work week ── */}
      <Card>
        <CardHeader>
          <CardTitle>{t("weekly_schedule_section")}</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2">
          <p className="text-body-md text-muted-foreground">
            {t("week_start_day_hint")}
          </p>
          <div className="space-y-1.5">
            <Label>{t("week_start_day_label")}</Label>
            <Select
              value={String(weekStart)}
              onValueChange={(v) => set("week_start_day", Number(v ?? "6"))}
            >
              <SelectTrigger className="w-full">
                <SelectValue>
                  {(v) =>
                    t(
                      WEEKDAYS.find((d) => String(d.value) === v)?.key ??
                        "weekday_sat",
                    )
                  }
                </SelectValue>
              </SelectTrigger>
              <SelectContent>
                {WEEKDAYS.map((d) => (
                  <SelectItem key={d.value} value={String(d.value)}>
                    {t(d.key)}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
        </CardContent>
      </Card>

      {/* ── Documents / letterhead ── */}
      <Card>
        <CardHeader>
          <CardTitle>{t("company_documents")}</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <p className="text-body-md text-muted-foreground">
            {t("company_documents_hint")}
          </p>
          <div className="space-y-1.5">
            <Label>{t("commercial_register")}</Label>
            <Input
              value={form.commercial_register ?? ""}
              onChange={(e) => set("commercial_register", e.target.value)}
            />
          </div>
          <div className="space-y-1.5">
            <Label>{t("company_phone_label")}</Label>
            <Input
              value={form.company_phone ?? ""}
              onChange={(e) => set("company_phone", e.target.value)}
            />
          </div>
          <div className="space-y-1.5">
            <Label>{t("company_address_label")}</Label>
            <Input
              value={form.company_address ?? ""}
              onChange={(e) => set("company_address", e.target.value)}
            />
          </div>
        </CardContent>
      </Card>

      <Button onClick={onSave} disabled={update.isPending}>
        {update.isPending ? t("saving") : t("save_changes")}
      </Button>
    </div>
  );
}
