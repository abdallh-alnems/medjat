"use client";

import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { PasswordInput } from "@/components/ui/password-input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { useT } from "@/lib/i18n/use-t";
import { ApiError, login, phoneSchema } from "@/features/employee-attendance/api";

const REMEMBERED_PHONE = "medjat_emp_phone";

export default function EmployeeLoginPage() {
  const { t, dir } = useT();
  const router = useRouter();

  const phoneRef = useRef<HTMLInputElement | null>(null);
  const [pin, setPin] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [locked, setLocked] = useState(false);
  const [busy, setBusy] = useState(false);

  // The phone is remembered, the PIN never is. Sessions end at every check-out,
  // so an employee signs in daily — retyping a number they have typed a hundred
  // times is friction with no security value.
  //
  // Written straight to the DOM rather than into state: the value only exists in
  // the browser, so seeding React state with it would make the server-rendered
  // markup and the first client render disagree.
  useEffect(() => {
    const saved = window.localStorage.getItem(REMEMBERED_PHONE);
    if (saved && phoneRef.current && phoneRef.current.value === "") {
      phoneRef.current.value = saved;
    }
  }, []);

  async function onSubmit(event: React.FormEvent) {
    event.preventDefault();
    setError(null);
    setLocked(false);

    const phone = phoneRef.current?.value.trim() ?? "";
    if (!phoneSchema.safeParse(phone).success) {
      setError(t("emp_phone_required"));
      return;
    }
    if (!/^\d{6}$/.test(pin)) {
      setError(t("emp_pin_must_be_six_digits"));
      return;
    }

    setBusy(true);
    try {
      await login({ phone, pin });
      window.localStorage.setItem(REMEMBERED_PHONE, phone);
      router.replace("/me/attendance");
    } catch (err) {
      if (err instanceof ApiError) {
        // A locked account gets its own state: repeating "wrong PIN" to someone
        // who is locked out sends them round the same loop until they give up
        // and call support.
        if (err.code === "web_pin_locked" || err.status === 423) {
          setLocked(true);
        } else if (err.code === "not_activated" || err.status === 404) {
          router.replace("/me/activate");
          return;
        } else {
          setError(err.message);
        }
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
        <CardTitle>{t("emp_sign_in")}</CardTitle>
      </CardHeader>
      <CardContent>
        <form onSubmit={onSubmit} className="space-y-4">
          <div className="space-y-1.5">
            <Label htmlFor="phone">{t("emp_phone")}</Label>
            <Input
              ref={phoneRef}
              id="phone"
              name="phone"
              type="tel"
              inputMode="tel"
              autoComplete="username"
              dir="ltr"
              defaultValue=""
              disabled={busy}
            />
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="pin">{t("emp_pin")}</Label>
            <PasswordInput
              id="pin"
              name="pin"
              inputMode="numeric"
              autoComplete="current-password"
              maxLength={6}
              dir="ltr"
              value={pin}
              onChange={(e) => setPin(e.target.value.replace(/\D/g, ""))}
              disabled={busy}
            />
          </div>

          {locked && (
            <p role="alert" className="text-sm text-destructive">
              {t("emp_contact_admin")}
            </p>
          )}
          {error && !locked && (
            <p role="alert" className="text-sm text-destructive">
              {error}
            </p>
          )}

          <Button type="submit" className="w-full" disabled={busy}>
            {busy ? t("loading") : t("emp_sign_in")}
          </Button>

          <Link
            href="/me/activate"
            className="block text-center text-sm text-muted-foreground underline"
          >
            {t("emp_first_time")}
          </Link>
        </form>
      </CardContent>
    </Card>
  );
}
