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
import { Separator } from "@/components/ui/separator";
import { useT } from "@/lib/i18n/use-t";
import { useAuth } from "@/lib/hooks/use-auth";
import {
  signInEmail,
  signInWithGoogle,
  signInWithApple,
} from "@/lib/firebase/auth";
import { toast } from "sonner";
import Link from "next/link";
import { Loader2 } from "lucide-react";

const schema = z.object({
  email: z.string().email(),
  password: z.string().min(6),
});
type FormData = z.infer<typeof schema>;

export default function LoginPage() {
  const router = useRouter();
  const { t } = useT();
  const { completeLogin } = useAuth();
  const [busy, setBusy] = useState<"email" | "google" | "apple" | null>(null);

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<FormData>({
    resolver: zodResolver(schema),
    defaultValues: { email: "", password: "" },
  });

  async function onEmailSubmit(data: FormData) {
    setBusy("email");
    try {
      await signInEmail(data.email, data.password);
      await completeLogin();
      toast.success(t("welcome_back"));
      router.replace("/dashboard");
    } catch {
      toast.error(t("invalid_credentials"));
    } finally {
      setBusy(null);
    }
  }

  async function onGoogle() {
    setBusy("google");
    try {
      await signInWithGoogle();
      await completeLogin();
      router.replace("/dashboard");
    } catch {
      toast.error(t("error_generic"));
    } finally {
      setBusy(null);
    }
  }

  async function onApple() {
    setBusy("apple");
    try {
      await signInWithApple();
      await completeLogin();
      router.replace("/dashboard");
    } catch {
      toast.error(t("error_generic"));
    } finally {
      setBusy(null);
    }
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-headline-md">{t("login")}</CardTitle>
        <CardDescription>{t("welcome_back")}</CardDescription>
      </CardHeader>
      <form onSubmit={handleSubmit(onEmailSubmit)}>
        <CardContent className="space-y-3">
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
          <div className="space-y-1.5">
            <Label htmlFor="password">{t("password")}</Label>
            <Input
              id="password"
              type="password"
              autoComplete="current-password"
              placeholder={t("enter_password")}
              {...register("password")}
            />
            {errors.password && (
              <p className="text-label-sm text-destructive">
                {t("min_password_length")}
              </p>
            )}
          </div>
          <Link
            href="/forgot-password"
            className="inline-block text-label-md text-brand hover:underline"
          >
            {t("forgot_password")}
          </Link>
        </CardContent>
        <CardFooter className="flex flex-col gap-3">
          <Button type="submit" className="w-full" disabled={busy !== null}>
            {busy === "email" && <Loader2 className="h-4 w-4 animate-spin" />}
            {t("login")}
          </Button>
        </CardFooter>
      </form>
      <div className="flex items-center gap-3 px-6 pb-3">
        <Separator className="flex-1" />
        <span className="text-label-sm text-muted-foreground">{t("or")}</span>
        <Separator className="flex-1" />
      </div>
      <CardContent className="flex flex-col gap-2 pb-6">
        <Button
          type="button"
          variant="outline"
          onClick={onGoogle}
          disabled={busy !== null}
        >
          {busy === "google" && <Loader2 className="h-4 w-4 animate-spin" />}
          {t("continue_with_google")}
        </Button>
        <Button
          type="button"
          variant="outline"
          onClick={onApple}
          disabled={busy !== null}
        >
          {busy === "apple" && <Loader2 className="h-4 w-4 animate-spin" />}
          {t("continue_with_apple")}
        </Button>
        <p className="mt-2 text-center text-label-md text-muted-foreground">
          {t("no_account")}{" "}
          <Link href="/signup" className="text-brand hover:underline">
            {t("signup")}
          </Link>
        </p>
      </CardContent>
    </Card>
  );
}
