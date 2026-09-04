"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { PasswordInput } from "@/components/ui/password-input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { useT } from "@/lib/i18n/use-t";
import { ApiError, activate, phoneSchema, pinRejectReason } from "@/features/employee-attendance/api";

/**
 * First-ever browser sign-in: spend the activation code, choose the PIN.
 *
 * The code is single-use, so this page runs once per employee — every later
 * sign-in is `/login`.
 */
export default function EmployeeActivatePage() {
  const { t, dir } = useT();
  const router = useRouter();

  const [phone, setPhone] = useState("");
  const [code, setCode] = useState("");
  const [pin, setPin] = useState("");
  const [confirm, setConfirm] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function onSubmit(event: React.FormEvent) {
    event.preventDefault();
    setError(null);

    if (!phoneSchema.safeParse(phone).success) {
      setError(t("emp_phone_required"));
      return;
    }

    // Tell them *which* rule failed. "Invalid PIN" sends someone straight to
    // another guessable choice.
    const reject = pinRejectReason(pin);
    if (reject) {
      setError(t(`emp_pin_reject_${reject}` as never));
      return;
    }

    // Checked before the request, because a mistyped PIN here is unrecoverable
    // without an administrator: the activation code is spent either way.
    if (pin !== confirm) {
      setError(t("emp_pin_mismatch"));
      return;
    }

    setBusy(true);
    try {
      await activate({ phone: phone.trim(), activation_code: code.trim(), pin });
      window.localStorage.setItem("permedjat_emp_phone", phone.trim());
      router.replace("/me/attendance");
    } catch (err) {
      if (err instanceof ApiError) {
        // Already activated — the employee wants /login, not this page.
        if (err.code === "already_activated" || err.status === 409) {
          router.replace("/me/login");
          return;
        }
        setError(err.message);
      } else {
        setError(t("error"));
      }
    } finally {
      setBusy(false);
    }
  }

  return (
    <Card dir={dir}>
      <CardHeader>
        <CardTitle>{t("emp_activate_title")}</CardTitle>
      </CardHeader>
      <CardContent>
        <p className="mb-4 text-sm text-muted-foreground">{t("emp_activate_hint")}</p>

        <form onSubmit={onSubmit} className="space-y-4">
          <div className="space-y-1.5">
            <Label htmlFor="phone">{t("emp_phone")}</Label>
            <Input
              id="phone"
              type="tel"
              inputMode="tel"
              dir="ltr"
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
              disabled={busy}
            />
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="code">{t("emp_activation_code")}</Label>
            <Input
              id="code"
              dir="ltr"
              autoCapitalize="characters"
              value={code}
              onChange={(e) => setCode(e.target.value.toUpperCase())}
              disabled={busy}
            />
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="pin">{t("emp_pin")}</Label>
            <PasswordInput
              id="pin"
              inputMode="numeric"
              maxLength={6}
              dir="ltr"
              autoComplete="new-password"
              value={pin}
              onChange={(e) => setPin(e.target.value.replace(/\D/g, ""))}
              disabled={busy}
            />
            <p className="text-xs text-muted-foreground">{t("emp_pin_rule")}</p>
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="confirm">{t("emp_pin_confirm")}</Label>
            <PasswordInput
              id="confirm"
              inputMode="numeric"
              maxLength={6}
              dir="ltr"
              autoComplete="new-password"
              value={confirm}
              onChange={(e) => setConfirm(e.target.value.replace(/\D/g, ""))}
              disabled={busy}
            />
          </div>

          {error && (
            <p role="alert" className="text-sm text-destructive">
              {error}
            </p>
          )}

          <Button type="submit" className="w-full" disabled={busy}>
            {busy ? t("loading") : t("emp_activate_title")}
          </Button>

          <Link href="/me/login" className="block text-center text-sm text-muted-foreground underline">
            {t("emp_have_pin")}
          </Link>
        </form>
      </CardContent>
    </Card>
  );
}
