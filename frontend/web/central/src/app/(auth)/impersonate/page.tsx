"use client";

/**
 * Support-desk diagnostic sign-in landing page.
 *
 * The super-admin panel mints a one-hour Firebase custom token for a specific
 * company administrator and opens this page with it. We exchange the token for
 * a real session and then follow exactly the same path as a normal login, so
 * what the support agent sees is what the client sees — which is the entire
 * point of the feature.
 *
 * The token never reaches this page unless a super admin asked for it with a
 * stated reason, and that request is written to the company's own audit log.
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
import { signInWithSupportToken } from "@/lib/firebase/auth";
import { Loader2, ShieldAlert } from "lucide-react";

function ImpersonateInner() {
  const router = useRouter();
  const params = useSearchParams();
  const { completeLogin } = useAuth();
  const token = params.get("token");
  const [signInError, setSignInError] = useState<string | null>(null);
  // A missing token is knowable during render, so it is derived rather than
  // pushed into state from an effect.
  const error = token ? signInError : "رابط الدخول التشخيصي غير مكتمل — لا يوجد رمز.";
  // React StrictMode mounts effects twice in dev; a custom token is single-use
  // in practice, so the second run must not fire.
  const started = useRef(false);

  useEffect(() => {
    if (started.current || !token) return;
    started.current = true;

    (async () => {
      try {
        await signInWithSupportToken(token);
        await completeLogin();
        router.replace("/dashboard");
      } catch (err) {
        console.error("Support sign-in failed:", err);
        const code = (err as { code?: string })?.code ?? "";
        setSignInError(
          code === "auth/invalid-custom-token" || code === "auth/custom-token-mismatch"
            ? "الرمز غير صالح لهذا التطبيق."
            : code === "auth/network-request-failed"
              ? "تعذّر الاتصال بالخادم."
              : "انتهت صلاحية الرمز أو استُخدم بالفعل. اطلب رمزًا جديدًا من لوحة التحكم.",
        );
      }
    })();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <Card>
      <CardHeader className="items-center text-center">
        <div className="mb-2 flex size-12 items-center justify-center rounded-full bg-warning/10 text-warning">
          {error ? <ShieldAlert className="size-6" /> : <Loader2 className="size-6 animate-spin" />}
        </div>
        <CardTitle>دخول تشخيصي للدعم</CardTitle>
        <CardDescription>
          {error ?? "جارٍ فتح حساب الشركة للفحص…"}
        </CardDescription>
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

export default function ImpersonatePage() {
  return (
    <Suspense
      fallback={
        <Card>
          <CardHeader className="items-center text-center">
            <Loader2 className="size-6 animate-spin" />
            <CardTitle>دخول تشخيصي للدعم</CardTitle>
          </CardHeader>
        </Card>
      }
    >
      <ImpersonateInner />
    </Suspense>
  );
}
