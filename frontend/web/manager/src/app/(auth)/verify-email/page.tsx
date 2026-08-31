"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { useT } from "@/lib/i18n/use-t";
import { resendEmailVerification } from "@/lib/firebase/auth";
import { auth } from "@/lib/firebase/config";
import { useAuth } from "@/lib/hooks/use-auth";
import { toast } from "sonner";
import { Loader2, MailCheck } from "lucide-react";

export default function VerifyEmailPage() {
  const router = useRouter();
  const { t } = useT();
  const { completeLogin } = useAuth();
  const [busy, setBusy] = useState(false);

  async function resend() {
    const user = auth.currentUser;
    if (!user) {
      router.replace("/login");
      return;
    }
    setBusy(true);
    try {
      await resendEmailVerification(user);
      toast.success(t("email_verification_sent"));
    } finally {
      setBusy(false);
    }
  }

  async function checkAndContinue() {
    setBusy(true);
    try {
      await auth.currentUser?.reload();
      if (auth.currentUser?.emailVerified) {
        await completeLogin();
        router.replace("/dashboard");
      } else {
        toast.error(t("email_not_verified"));
      }
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
        <CardTitle className="text-headline-md">{t("verify_email")}</CardTitle>
        <CardDescription>{t("verify_email_message")}</CardDescription>
      </CardHeader>
      <CardContent />
      <CardFooter className="flex flex-col gap-2">
        <Button className="w-full" onClick={checkAndContinue} disabled={busy}>
          {busy && <Loader2 className="h-4 w-4 animate-spin" />}
          {t("confirm")}
        </Button>
        <Button
          variant="ghost"
          className="w-full"
          onClick={resend}
          disabled={busy}
        >
          {t("resend_verification")}
        </Button>
      </CardFooter>
    </Card>
  );
}
