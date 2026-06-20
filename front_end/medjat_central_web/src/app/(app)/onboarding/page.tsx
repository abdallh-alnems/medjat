"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
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
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { useT } from "@/lib/i18n/use-t";
import { createCompany, joinCompany } from "@/lib/api/tenant";
import { useTenantStore } from "@/lib/stores/tenant-store";
import { toast } from "sonner";
import { Building2, UserPlus, Loader2 } from "lucide-react";

const createSchema = z.object({
  name: z.string().min(2),
  phone: z.string().optional(),
});
const joinSchema = z.object({ code: z.string().min(4) });

export default function OnboardingPage() {
  const router = useRouter();
  const { t } = useT();
  const setTenant = useTenantStore((s) => s.setTenant);
  const [busy, setBusy] = useState(false);

  const createForm = useForm<z.infer<typeof createSchema>>({
    resolver: zodResolver(createSchema),
    defaultValues: { name: "", phone: "" },
  });
  const joinForm = useForm<z.infer<typeof joinSchema>>({
    resolver: zodResolver(joinSchema),
    defaultValues: { code: "" },
  });

  async function onCreate(data: z.infer<typeof createSchema>) {
    setBusy(true);
    try {
      const res = await createCompany(data.name, data.phone);
      if (res.tenant_id) setTenant(res.tenant_id, data.name);
      toast.success(t("success"));
      router.replace("/dashboard");
    } catch {
      toast.error(t("error_generic"));
    } finally {
      setBusy(false);
    }
  }

  async function onJoin(data: z.infer<typeof joinSchema>) {
    setBusy(true);
    try {
      const res = await joinCompany(data.code);
      if (res.tenant_id) setTenant(res.tenant_id, res.company?.name);
      toast.success(t("success"));
      router.replace("/dashboard");
    } catch {
      toast.error(t("error_generic"));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="mx-auto max-w-lg">
      <Card>
        <CardHeader className="text-center">
          <CardTitle className="text-headline-md">
            {t("onboarding_title")}
          </CardTitle>
          <CardDescription>{t("welcome_back")}</CardDescription>
        </CardHeader>
        <CardContent>
          <Tabs defaultValue="create">
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
        </CardContent>
      </Card>
    </div>
  );
}
