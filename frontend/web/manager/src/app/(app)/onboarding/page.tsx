"use client";

import { Suspense, useMemo, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  CURRENCIES,
  WEEKDAYS,
  currencyForZone,
  detectTimezone,
  supportedZones,
  weekStartForZone,
} from "@/lib/locale-defaults";
import { useT } from "@/lib/i18n/use-t";
import { createCompany, joinCompany, acceptInvitation } from "@/lib/api/tenant";
import { useTenantStore } from "@/lib/stores/tenant-store";
import { useAuthStore, type AdminRole } from "@/lib/stores/auth-store";
import { toast } from "sonner";
import { Building2, UserPlus, Loader2, LifeBuoy, MailCheck } from "lucide-react";
import type { TKey } from "@/lib/i18n/ar";

const SUPPORT_EMAIL = "support@permedjat.com";

const ROLE_KEY: Record<AdminRole, TKey> = {
  general_manager: "general_manager",
  hr: "hr",
  branch_manager: "branch_manager",
  attendance: "attendance_role",
  viewer: "viewer",
};

const createSchema = z.object({
  name: z.string().min(2),
  phone: z.string().optional(),
});
const joinSchema = z.object({ code: z.string().min(4) });

const CYCLE_DAYS = Array.from({ length: 28 }, (_, i) => i + 1);

function OnboardingInner() {
  const router = useRouter();
  const { t } = useT();
  const setTenant = useTenantStore((s) => s.setTenant);
  const pendingInvitation = useAuthStore((s) => s.pendingInvitation);
  const setPendingInvitation = useAuthStore((s) => s.setPendingInvitation);
  const [busy, setBusy] = useState(false);

  // The invitation email links to /onboarding?code=XXXX — pre-fill the join tab.
  const initialCode = useSearchParams().get("code") ?? "";
  const [tab, setTab] = useState(initialCode ? "join" : "create");

  const createForm = useForm<z.infer<typeof createSchema>>({
    resolver: zodResolver(createSchema),
    defaultValues: { name: "", phone: "" },
  });

  // Locale settings are captured here rather than left to the column defaults:
  // attendance is stamped on the company's clock, so a company that never picks
  // a timezone silently records every check-in against the wrong one. Seeded
  // from the browser so the common case is one glance, not four decisions.
  const [detectedZone] = useState(detectTimezone);
  const zones = useMemo(() => supportedZones(detectedZone), [detectedZone]);
  const [timezone, setTimezone] = useState(detectedZone);
  const [currency, setCurrency] = useState<string>(() =>
    currencyForZone(detectedZone),
  );
  const [cycleStartDay, setCycleStartDay] = useState(1);
  const [weekStartDay, setWeekStartDay] = useState(() =>
    weekStartForZone(detectedZone),
  );
  const joinForm = useForm<z.infer<typeof joinSchema>>({
    resolver: zodResolver(joinSchema),
    defaultValues: { code: initialCode },
  });

  function finishOnboarding(
    tenantId: number,
    name?: string,
  ) {
    setPendingInvitation(null);
    setTenant(tenantId, name);
    toast.success(t("success"));
    router.replace("/dashboard");
  }

  async function onAcceptInvitation() {
    setBusy(true);
    try {
      const res = await acceptInvitation(pendingInvitation?.invitation_id);
      if (res.tenant?.id) {
        finishOnboarding(res.tenant.id, res.tenant.name);
      } else {
        toast.error(res.message || t("error_generic"));
      }
    } catch (err) {
      console.error("Failed to accept invitation:", err);
      toast.error(t("error_generic"));
    } finally {
      setBusy(false);
    }
  }

  async function onCreate(data: z.infer<typeof createSchema>) {
    setBusy(true);
    try {
      const res = await createCompany(data.name, {
        timezone,
        currency,
        cycle_start_day: cycleStartDay,
        week_start_day: weekStartDay,
      });
      if (res.tenant?.id) {
        finishOnboarding(res.tenant.id, res.tenant.name);
      } else {
        toast.error(res.message || t("error_generic"));
      }
    } catch (err) {
      console.error("Failed to create company:", err);
      toast.error(t("error_generic"));
    } finally {
      setBusy(false);
    }
  }

  async function onJoin(data: z.infer<typeof joinSchema>) {
    setBusy(true);
    try {
      const res = await joinCompany(data.code);
      if (res.tenant?.id) {
        finishOnboarding(res.tenant.id, res.tenant.name);
      } else {
        toast.error(res.message || t("error_generic"));
      }
    } catch (err) {
      console.error("Failed to join company:", err);
      toast.error(t("error_generic"));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="mx-auto max-w-lg space-y-4">
      {pendingInvitation && (
        <Card className="border-primary/40 bg-primary/5">
          <CardContent className="flex flex-col gap-3 py-4 sm:flex-row sm:items-center sm:justify-between">
            <div className="flex items-start gap-3">
              <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-primary/10">
                <MailCheck className="h-5 w-5 text-primary" />
              </div>
              <div className="space-y-1">
                <p className="text-body-md font-medium">
                  {t("pending_invitation_title")}
                </p>
                <p className="text-body-sm text-muted-foreground">
                  {pendingInvitation.company_name}
                  {" · "}
                  <Badge variant="secondary">
                    {t(ROLE_KEY[pendingInvitation.role] ?? "viewer")}
                  </Badge>
                </p>
              </div>
            </div>
            <Button
              onClick={onAcceptInvitation}
              disabled={busy}
              className="shrink-0"
            >
              {busy && <Loader2 className="h-4 w-4 animate-spin" />}
              {t("accept_and_join")}
            </Button>
          </CardContent>
        </Card>
      )}

      <Card>
        <CardHeader className="text-center">
          <CardTitle className="text-headline-md">
            {t("onboarding_title")}
          </CardTitle>
          <CardDescription>{t("onboarding_subtitle")}</CardDescription>
        </CardHeader>
        <CardContent>
          <Tabs value={tab} onValueChange={setTab}>
            <TabsList className="grid w-full grid-cols-2">
              <TabsTrigger value="create">
                <Building2 className="h-4 w-4" />
                {t("create_company")}
              </TabsTrigger>
              <TabsTrigger value="join">
                <UserPlus className="h-4 w-4" />
                {t("join_company")}
              </TabsTrigger>
            </TabsList>

            <TabsContent value="create">
              <form
                onSubmit={createForm.handleSubmit(onCreate)}
                className="mt-4 space-y-3"
              >
                <p className="text-body-sm text-muted-foreground">
                  {t("create_company_desc")}
                </p>
                <div className="space-y-1.5">
                  <Label htmlFor="name">{t("company_name")}</Label>
                  <Input id="name" {...createForm.register("name")} />
                  {createForm.formState.errors.name && (
                    <p className="text-label-sm text-destructive">
                      {t("required")}
                    </p>
                  )}
                </div>
                <div className="space-y-1.5">
                  <Label htmlFor="phone">{t("phone")}</Label>
                  <Input id="phone" {...createForm.register("phone")} />
                </div>

                <div className="space-y-3 rounded-lg border p-3">
                  <p className="text-label-sm text-muted-foreground">
                    {t("onboarding_locale_hint")}
                  </p>

                  <div className="space-y-1.5">
                    <Label>{t("timezone_label")}</Label>
                    <Select
                      value={timezone}
                      onValueChange={(v) => {
                        const zone = (v as string) || "Africa/Cairo";
                        setTimezone(zone);
                        setCurrency(currencyForZone(zone));
                        setWeekStartDay(weekStartForZone(zone));
                      }}
                    >
                      <SelectTrigger className="w-full">
                        <SelectValue>
                          {(v) => ((v as string) || "").replace(/_/g, " ")}
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

                  <div className="grid grid-cols-2 gap-3">
                    <div className="space-y-1.5">
                      <Label>{t("currency_label")}</Label>
                      <Select
                        value={currency}
                        onValueChange={(v) => setCurrency((v as string) || "EGP")}
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
                      <Label>{t("cycle_start_day_label")}</Label>
                      <Select
                        value={String(cycleStartDay)}
                        onValueChange={(v) =>
                          setCycleStartDay(Number(v as string) || 1)
                        }
                      >
                        <SelectTrigger className="w-full">
                          <SelectValue>{(v) => (v as string) || "1"}</SelectValue>
                        </SelectTrigger>
                        <SelectContent className="max-h-72">
                          {CYCLE_DAYS.map((d) => (
                            <SelectItem key={d} value={String(d)}>
                              {d}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    </div>
                  </div>

                  <div className="space-y-1.5">
                    <Label>{t("week_start_day_label")}</Label>
                    <Select
                      value={String(weekStartDay)}
                      onValueChange={(v) =>
                        setWeekStartDay(Number(v as string) || 6)
                      }
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
                </div>

                <Button type="submit" className="w-full" disabled={busy}>
                  {busy && <Loader2 className="h-4 w-4 animate-spin" />}
                  {t("create_company")}
                </Button>
              </form>
            </TabsContent>

            <TabsContent value="join">
              <form
                onSubmit={joinForm.handleSubmit(onJoin)}
                className="mt-4 space-y-3"
              >
                <p className="text-body-sm text-muted-foreground">
                  {t("join_company_desc")}
                </p>
                <div className="space-y-1.5">
                  <Label htmlFor="code">{t("invite_code")}</Label>
                  <Input
                    id="code"
                    placeholder={t("enter_invite_code")}
                    {...joinForm.register("code")}
                  />
                  {joinForm.formState.errors.code && (
                    <p className="text-label-sm text-destructive">
                      {t("required")}
                    </p>
                  )}
                </div>
                <Button type="submit" className="w-full" disabled={busy}>
                  {busy && <Loader2 className="h-4 w-4 animate-spin" />}
                  {t("join_via_code")}
                </Button>
              </form>
            </TabsContent>
          </Tabs>

          <div className="mt-6 flex flex-col items-center gap-1 border-t pt-4">
            <span className="text-label-sm text-muted-foreground">
              {t("need_help_question")}
            </span>
            <a
              href={`mailto:${SUPPORT_EMAIL}?subject=${encodeURIComponent(
                t("support_email_subject"),
              )}`}
              className="inline-flex items-center gap-1.5 text-body-sm font-medium text-primary hover:underline"
            >
              <LifeBuoy className="h-4 w-4" />
              {t("contact_support")}
            </a>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}

export default function OnboardingPage() {
  // useSearchParams (read inside OnboardingInner) needs a Suspense boundary.
  return (
    <Suspense fallback={null}>
      <OnboardingInner />
    </Suspense>
  );
}
