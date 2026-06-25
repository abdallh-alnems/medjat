"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useT } from "@/lib/i18n/use-t";
import { useUIStore } from "@/lib/stores/ui-store";
import { useAuthStore } from "@/lib/stores/auth-store";
import { useTheme } from "next-themes";
import { useToastMutation } from "@/lib/hooks/use-org";
import { deleteAccount } from "@/lib/api/auth";
import { signOut } from "@/lib/firebase/auth";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
  DialogClose,
} from "@/components/ui/dialog";
import { Label } from "@/components/ui/label";
import { Globe, Moon, Sun, Laptop, AlertTriangle } from "lucide-react";

export default function AccountPage() {
  const { t } = useT();
  const router = useRouter();
  const locale = useUIStore((s) => s.locale);
  const setLocale = useUIStore((s) => s.setLocale);
  const user = useAuthStore((s) => s.user);
  const logout = useAuthStore((s) => s.logout);
  const { theme, setTheme } = useTheme();

  const [confirmOpen, setConfirmOpen] = useState(false);
  const del = useToastMutation(() => deleteAccount(), {
    onSuccess: async () => {
      try {
        await signOut();
      } catch {
        /* firebase may be uninitialized */
      }
      logout();
      router.replace("/login");
    },
  });

  const isGM = user?.role === "general_manager";

  return (
    <div className="mx-auto max-w-2xl space-y-4">
      <h1 className="text-headline-md font-bold">{t("account")}</h1>

      <Card>
        <CardHeader>
          <CardTitle>{t("profile")}</CardTitle>
        </CardHeader>
        <CardContent className="space-y-1">
          <p className="font-medium">{user?.name}</p>
          <p className="text-body-md text-muted-foreground">{user?.email}</p>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>{t("preferences")}</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="space-y-1.5">
            <Label>{t("language")}</Label>
            <Select
              value={locale}
              onValueChange={(v) => setLocale((v ?? "ar") as "ar" | "en")}
            >
              <SelectTrigger className="w-40">
                <Globe className="me-2 h-4 w-4" />
                <SelectValue>
                  {(v) => (v === "en" ? t("english") : t("arabic"))}
                </SelectValue>
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="ar">{t("arabic")}</SelectItem>
                <SelectItem value="en">{t("english")}</SelectItem>
              </SelectContent>
            </Select>
          </div>

          <div className="space-y-1.5">
            <Label>{t("appearance")}</Label>
            <div className="flex gap-2">
              {([
                { v: "light", icon: Sun, label: t("light") },
                { v: "dark", icon: Moon, label: t("dark") },
                { v: "system", icon: Laptop, label: t("system") },
              ] as const).map((opt) => {
                const Icon = opt.icon;
                return (
                  <Button
                    key={opt.v}
                    variant={theme === opt.v ? "default" : "outline"}
                    size="sm"
                    onClick={() => setTheme(opt.v)}
                  >
                    <Icon className="h-4 w-4" />
                    {opt.label}
                  </Button>
                );
              })}
            </div>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle className="text-destructive">{t("delete_account")}</CardTitle>
        </CardHeader>
        <CardContent className="space-y-3">
          <p className="text-body-md text-muted-foreground">
            {t("delete_account_confirm_message")}
          </p>
          {isGM && (
            <p className="flex items-start gap-2 rounded-lg border border-destructive/40 bg-destructive/5 p-3 text-body-md text-destructive">
              <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" />
              {t("delete_account_warning_company")}
            </p>
          )}
          <Button variant="destructive" onClick={() => setConfirmOpen(true)}>
            {t("delete_account")}
          </Button>
        </CardContent>
      </Card>

      <Dialog open={confirmOpen} onOpenChange={setConfirmOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{t("delete_account_confirm_title")}</DialogTitle>
            <DialogDescription>
              {t("delete_account_confirm_message")}
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <DialogClose render={<Button variant="outline" />}>
              {t("cancel")}
            </DialogClose>
            <Button
              variant="destructive"
              onClick={() => del.mutate(undefined)}
              disabled={del.isPending}
            >
              {del.isPending ? t("saving") : t("delete_account")}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
