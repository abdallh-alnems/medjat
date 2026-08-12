"use client";

/**
 * Desktop sign-in landing page — opened inside the desktop app window.
 *
 * The user signed in in their real browser (where passkeys work; Electron
 * reports no platform authenticator, so they cannot), the browser handed a
 * single-use code back over medjat://auth, and the app opened this page with it.
 * We trade the code for a Firebase custom token and then follow the ordinary
 * login path, so the session that results is indistinguishable from any other.
 *
 * The code is single-use, expires in two minutes, and is bound to the nonce the
 * desktop app generated, so it is worthless to anyone who intercepts it alone.
 */

import { useEffect, useRef, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense } from "react";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { useAuth } from "@/lib/hooks/use-auth";
import { signInWithDesktopToken } from "@/lib/firebase/auth";
import { desktopExchange } from "@/lib/api/auth";
import { Loader2, ShieldAlert } from "lucide-react";

function DesktopAuthInner() {
  const router = useRouter();
  const params = useSearchParams();
  const { completeLogin } = useAuth();
  const code = params.get("code");
  const state = params.get("state");
  const [signInError, setSignInError] = useState<string | null>(null);
  const error =
    code && state ? signInError : "رابط الدخول غير مكتمل — أعد المحاولة من التطبيق.";
  // StrictMode mounts effects twice in dev; the code is single-use, so the
  // second run must not spend it.
  const started = useRef(false);

  useEffect(() => {
    if (started.current || !code || !state) return;
    started.current = true;

    (async () => {
      try {
        const { token } = await desktopExchange(code, state);
        await signInWithDesktopToken(token);
        await completeLogin();
        router.replace("/dashboard");
      } catch (err) {
        console.error("Desktop sign-in failed:", err);
        setSignInError(
          "انتهت صلاحية رمز الدخول أو استُخدم بالفعل. ابدأ تسجيل الدخول من التطبيق مرة أخرى.",
        );
      }
    })();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <Card>
      <CardHeader className="items-center text-center">
        <div className="mb-2 flex size-12 items-center justify-center rounded-full bg-primary/10 text-primary">
          {error ? <ShieldAlert className="size-6" /> : <Loader2 className="size-6 animate-spin" />}
        </div>
        <CardTitle>تسجيل الدخول</CardTitle>
        <CardDescription>{error ?? "جارٍ إتمام تسجيل الدخول…"}</CardDescription>
      </CardHeader>
      {error && (
        <CardContent className="flex justify-center">
          <Button variant="outline" onClick={() => router.replace("/login")}>
            العودة لتسجيل الدخول
          </Button>
        </CardContent>
      )}
    </Card>
  );
}

export default function DesktopAuthPage() {
  return (
    <Suspense
      fallback={
        <Card>
          <CardHeader className="items-center text-center">
            <Loader2 className="size-6 animate-spin" />
            <CardTitle>تسجيل الدخول</CardTitle>
          </CardHeader>
        </Card>
      }
    >
      <DesktopAuthInner />
    </Suspense>
  );
}
