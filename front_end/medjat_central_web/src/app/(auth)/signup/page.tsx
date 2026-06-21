"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
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
import { useAuth } from "@/lib/hooks/use-auth";
import { signUpEmail, resendEmailVerification } from "@/lib/firebase/auth";
import { toast } from "sonner";
import Link from "next/link";
import { Loader2 } from "lucide-react";

const schema = z
  .object({
    name: z.string().min(2),
    email: z.string().email(),
    password: z.string().min(6),
    confirm: z.string().min(6),
  })
  .refine((d) => d.password === d.confirm, {
    path: ["confirm"],
    message: "mismatch",
  });
type FormData = z.infer<typeof schema>;

export default function SignupPage() {
  const router = useRouter();
  const { t } = useT();
  const { completeLogin } = useAuth();
  const [busy, setBusy] = useState(false);

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<FormData>({
    resolver: zodResolver(schema),
    defaultValues: { name: "", email: "", password: "", confirm: "" },
  });

  async function onSubmit(data: FormData) {
    setBusy(true);
    try {
      const cred = await signUpEmail(data.email, data.password);
      await resendEmailVerification(cred.user);
      try {
        await completeLogin();
      } catch {
        /* account created but no backend session yet — go to verify */
      }
      toast.success(t("email_verification_sent"));
      router.replace("/verify-email");
    } catch {
      toast.error(t("error_generic"));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-headline-md">{t("signup")}</CardTitle>
        <CardDescription>{t("create_account")}</CardDescription>
      </CardHeader>
      <form onSubmit={handleSubmit(onSubmit)}>
        <CardContent className="space-y-3">
          <div className="space-y-1.5">
            <Label htmlFor="name">{t("full_name")}</Label>
            <Input id="name" autoComplete="name" {...register("name")} />
            {errors.name && (
              <p className="text-label-sm text-destructive">{t("required")}</p>
            )}
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="email">{t("email")}</Label>
            <Input
              id="email"
              type="email"
              autoComplete="email"
              {...register("email")}
            />
            {errors.email && (
              <p className="text-label-sm text-destructive">
                {t("invalid_email")}
              </p>
            )}
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="password">{t("password")}</Label>
            <Input
              id="password"
              type="password"
              autoComplete="new-password"
              {...register("password")}
            />
            {errors.password && (
              <p className="text-label-sm text-destructive">
                {t("min_password_length")}
              </p>
            )}
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="confirm">{t("confirm_password")}</Label>
            <Input
              id="confirm"
              type="password"
              autoComplete="new-password"
              {...register("confirm")}
            />
            {errors.confirm && (
              <p className="text-label-sm text-destructive">
                {errors.confirm.message === "mismatch"
                  ? t("passwords_must_match")
                  : t("required")}
              </p>
            )}
          </div>
        </CardContent>
        <CardFooter className="flex flex-col gap-3">
          <Button type="submit" className="w-full" disabled={busy}>
            {busy && <Loader2 className="h-4 w-4 animate-spin" />}
            {t("signup")}
          </Button>
          <p className="text-label-md text-muted-foreground">
            {t("have_account")}{" "}
            <Link href="/login" className="text-brand hover:underline">
              {t("login")}
            </Link>
          </p>
        </CardFooter>
      </form>
    </Card>
  );
}
