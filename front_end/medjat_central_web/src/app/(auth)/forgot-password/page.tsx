"use client";

import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { useT } from "@/lib/i18n/use-t";
import { sendPasswordReset } from "@/lib/firebase/auth";
import { toast } from "sonner";
import { Loader2, MailCheck } from "lucide-react";
import Link from "next/link";

const schema = z.object({ email: z.string().email() });
type FormData = z.infer<typeof schema>;

export default function ForgotPasswordPage() {
  const { t } = useT();
  const [busy, setBusy] = useState(false);
  const [sent, setSent] = useState(false);

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<FormData>({
    resolver: zodResolver(schema),
    defaultValues: { email: "" },
  });

  async function onSubmit(data: FormData) {
    setBusy(true);
    try {
      await sendPasswordReset(data.email);
      toast.success(t("password_reset_sent"));
      setSent(true);
    } catch {
      toast.error(t("error_generic"));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Card>
      <CardHeader className="text-center">
        <div className="mx-auto mb-2 flex h-12 w-12 items-center justify-center rounded-full bg-brand-subtle text-brand">
          <MailCheck className="h-6 w-6" />
        </div>
        <CardTitle className="text-headline-md">
          {t("reset_password")}
        </CardTitle>
        <CardDescription>{t("reset_password_message")}</CardDescription>
      </CardHeader>
      <CardContent>
        {sent ? (
          <p className="text-center text-body-md text-muted-foreground">
            {t("password_reset_sent")}
          </p>
        ) : (
          <form id="reset" onSubmit={handleSubmit(onSubmit)} className="space-y-3">
            <div className="space-y-1.5">
              <Label htmlFor="email">{t("email")}</Label>
              <Input
                id="email"
                type="email"
                autoComplete="email"
                placeholder={t("enter_email")}
                {...register("email")}
              />
              {errors.email && (
                <p className="text-label-sm text-destructive">
                  {t("invalid_email")}
                </p>
              )}
            </div>
          </form>
        )}
      </CardContent>
      <CardFooter className="flex flex-col gap-2">
        {!sent && (
          <Button
            type="submit"
            form="reset"
            className="w-full"
            disabled={busy}
          >
            {busy && <Loader2 className="h-4 w-4 animate-spin" />}
            {t("send_reset_link")}
          </Button>
        )}
        <Link
          href="/login"
          className="text-label-md text-brand hover:underline"
        >
          {t("login")}
        </Link>
      </CardFooter>
    </Card>
  );
}
