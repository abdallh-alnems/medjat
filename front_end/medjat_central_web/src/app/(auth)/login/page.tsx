"use client";

import { useEffect, useState, useSyncExternalStore } from "react";
import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { PasswordInput } from "@/components/ui/password-input";
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
  consumeRedirectResult,
} from "@/lib/firebase/auth";
import { desktopAuthorize } from "@/lib/api/auth";
import { isDesktopApp } from "@/lib/desktop";
import { toast } from "sonner";
import Link from "next/link";
import { Loader2, Apple, ExternalLink } from "lucide-react";
import { GoogleIcon } from "@/components/ui/brand-icons";

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
  const [handedOff, setHandedOff] = useState(false);

  // Both values only exist in the browser. useSyncExternalStore reads them after
  // hydration without a Suspense boundary (which useSearchParams would require)
  // and without setting state from an effect.
  const subscribe = () => () => {};

  // Set when this page is the browser half of a desktop sign-in: the app opened
  // us with ?desktop=<nonce> and is waiting on medjat:// for the result.
  const desktopState = useSyncExternalStore(
    subscribe,
    () => new URLSearchParams(window.location.search).get("desktop"),
    () => null,
  );

  const inDesktopApp = useSyncExternalStore(subscribe, isDesktopApp, () => false);

  /**
   * Finishes a successful sign-in.
   *
   * Normally that means going to the dashboard. In the browser half of the
   * desktop flow it instead mints a single-use code and hands the session back
   * to the app, which is where the user actually wants to end up.
   */
  async function finishLogin(afterSession?: () => void) {
    await completeLogin();
    afterSession?.();

    if (desktopState) {
      try {
        const { code } = await desktopAuthorize(desktopState);
        setHandedOff(true);
        window.location.href =
          `medjat://auth?code=${encodeURIComponent(code)}` +
          `&state=${encodeURIComponent(desktopState)}`;
        return;
      } catch (err) {
        console.error("Desktop handoff failed:", err);
        toast.error("تعذّر إعادة تسجيل الدخول إلى التطبيق — أعد المحاولة من التطبيق.");
      }
    }

    router.replace("/dashboard");
  }

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<FormData>({
    resolver: zodResolver(schema),
    defaultValues: { email: "", password: "" },
  });

  // Complete a pending Google/Apple redirect sign-in when returning to this page.
  useEffect(() => {
    let cancelled = false;
    consumeRedirectResult()
      .then(async (user) => {
        if (!user || cancelled) return;
        setBusy("google");
        await finishLogin();
      })
      .catch((err) => {
        console.error("OAuth redirect sign-in failed:", err);
        const msg = oauthErrorMessage(err);
        if (msg) toast.error(msg);
        setBusy(null);
      });
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function onEmailSubmit(data: FormData) {
    setBusy("email");
    try {
      await signInEmail(data.email, data.password);
      await finishLogin(() => toast.success(t("welcome_back")));
    } catch (err) {
      const code = (err as { code?: string })?.code ?? "";
      const isCredential =
        code === "auth/invalid-credential" ||
        code === "auth/wrong-password" ||
        code === "auth/user-not-found" ||
        code === "auth/invalid-email";
      toast.error(isCredential ? t("invalid_credentials") : t("error_generic"));
    } finally {
      setBusy(null);
    }
  }

  /** Maps a Firebase OAuth error to a user message, or null when it should be silent. */
  function oauthErrorMessage(err: unknown): string | null {
    const code = (err as { code?: string })?.code ?? "";
    // The user simply closed/cancelled the popup — not a real failure.
    if (
      code === "auth/popup-closed-by-user" ||
      code === "auth/cancelled-popup-request" ||
      code === "auth/user-cancelled"
    ) {
      return null;
    }
    if (code === "auth/popup-blocked") return t("popup_blocked");
    if (code === "auth/unauthorized-domain") return t("oauth_domain_error");
    if (code === "auth/account-exists-with-different-credential")
      return t("account_exists_password");
    return t("error_generic");
  }

  async function onGoogle() {
    setBusy("google");
    try {
      const cred = await signInWithGoogle();
      if (!cred) return; // redirect fallback started; the page will navigate away
      await finishLogin();
    } catch (err) {
      console.error("Google sign-in failed:", err);
      const msg = oauthErrorMessage(err);
      if (msg) toast.error(msg);
      setBusy(null);
    }
  }

  async function onApple() {
    setBusy("apple");
    try {
      const cred = await signInWithApple();
      if (!cred) return; // redirect fallback started; the page will navigate away
      await finishLogin();
    } catch (err) {
      console.error("Apple sign-in failed:", err);
      const msg = oauthErrorMessage(err);
      if (msg) toast.error(msg);
      setBusy(null);
    }
  }

  // Browser half of the desktop flow: the session has been handed back over
  // medjat:// and this tab has nothing left to do.
  if (handedOff) {
    return (
      <Card>
        <CardHeader className="items-center text-center">
          <CardTitle className="text-headline-md">تم تسجيل الدخول</CardTitle>
          <CardDescription>
            ارجع إلى تطبيق Medjat Central — يمكنك إغلاق هذه الصفحة.
          </CardDescription>
        </CardHeader>
      </Card>
    );
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-headline-md">{t("login")}</CardTitle>
        <CardDescription>{t("welcome_back")}</CardDescription>
      </CardHeader>
      <form onSubmit={handleSubmit(onEmailSubmit)}>
        <CardContent className="space-y-4">
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
            <PasswordInput
              id="password"
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
          {busy === "google" ? (
            <Loader2 className="h-4 w-4 animate-spin" />
          ) : (
            <GoogleIcon className="h-4 w-4" />
          )}
          {t("continue_with_google")}
        </Button>
        <Button
          type="button"
          variant="outline"
          onClick={onApple}
          disabled={busy !== null}
        >
          {busy === "apple" ? (
            <Loader2 className="h-4 w-4 animate-spin" />
          ) : (
            <Apple className="h-4 w-4" />
          )}
          {t("continue_with_apple")}
        </Button>
        {/*
          Desktop only. Electron has no platform authenticator, so an account
          protected by a passkey cannot finish signing in in this window — the
          real browser can, and hands the session back over medjat://.
        */}
        {inDesktopApp && (
          <>
            <Button
              type="button"
              variant="ghost"
              onClick={() => window.medjat?.signInWithBrowser?.()}
              disabled={busy !== null}
            >
              <ExternalLink className="h-4 w-4" />
              تسجيل الدخول عبر المتصفح
            </Button>
            <p className="text-center text-label-sm text-muted-foreground">
              استخدم هذا الخيار إذا كان حسابك محمياً بمفتاح مرور (passkey).
            </p>
          </>
        )}
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
