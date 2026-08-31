"use client";

import { useState, useSyncExternalStore } from "react";
import Image from "next/image";
import Link from "next/link";
import {
  AppWindow,
  Check,
  Download,
  Info,
  Link2,
  LayoutGrid,
  Loader2,
  ShieldCheck,
} from "lucide-react";
import { Button, buttonVariants } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { useT } from "@/lib/i18n/use-t";
import type { TKey } from "@/lib/i18n/ar";
import { isDesktopApp } from "@/lib/desktop";
import {
  canInstallHere,
  getEnvironment,
  getInstallState,
  getServerInstallState,
  getServerEnvironment,
  promptInstall,
  subscribeEnvironment,
  subscribeInstall,
  type Browser,
  type Platform,
} from "@/lib/pwa-install";
import { toast } from "sonner";

/** The steps that match what this visitor is actually looking at. */
function stepsFor(platform: Platform, browser: Browser): TKey[] {
  if (platform === "ios") {
    return ["install_step_ios_1", "install_step_ios_2", "install_step_ios_3"];
  }
  if (platform === "android") {
    return ["install_step_android_1", "install_step_android_2"];
  }
  if (platform === "macos" && browser === "safari") {
    return ["install_step_mac_safari_1", "install_step_mac_safari_2"];
  }
  return ["install_step_win_1", "install_step_win_2", "install_step_win_3"];
}

const OTHER_PLATFORMS: { label: TKey; steps: TKey[] }[] = [
  {
    label: "install_other_windows",
    steps: ["install_step_win_1", "install_step_win_2", "install_step_win_3"],
  },
  {
    label: "install_other_macos_safari",
    steps: ["install_step_mac_safari_1", "install_step_mac_safari_2"],
  },
  {
    label: "install_other_macos_chrome",
    steps: ["install_step_win_1", "install_step_win_2", "install_step_win_3"],
  },
  {
    label: "install_other_ios",
    steps: ["install_step_ios_1", "install_step_ios_2", "install_step_ios_3"],
  },
  {
    label: "install_other_android",
    steps: ["install_step_android_1", "install_step_android_2"],
  },
];

export default function InstallPage() {
  const { t } = useT();
  const install = useSyncExternalStore(
    subscribeInstall,
    getInstallState,
    getServerInstallState,
  );

  /**
   * Platform detection has to wait for hydration — the server has no user agent,
   * and branching on it during the first render would mismatch. Null until then,
   * so every environment-dependent branch below stays neutral on the server.
   */
  const env = useSyncExternalStore(
    subscribeEnvironment,
    getEnvironment,
    getServerEnvironment,
  );
  const inDesktop = env !== null && isDesktopApp();
  const [busy, setBusy] = useState(false);

  async function onInstall() {
    setBusy(true);
    const outcome = await promptInstall();
    setBusy(false);
    if (outcome === "dismissed") toast.info(t("install_dismissed"));
  }

  async function onCopyLink() {
    try {
      await navigator.clipboard.writeText(window.location.href);
      toast.success(t("install_link_copied"));
    } catch {
      toast.error(t("error_generic"));
    }
  }

  const supported = env ? canInstallHere(env.platform, env.browser) : true;
  const steps = env ? stepsFor(env.platform, env.browser) : [];
  const finished = install.standalone || install.justInstalled;

  return (
    <main className="mx-auto w-full max-w-3xl px-4 py-10 sm:py-14">
      <header className="flex flex-col items-center text-center">
        <Image
          src="/logo.png"
          alt="Medjat Central"
          width={72}
          height={72}
          priority
          className="h-16 w-16 rounded-2xl shadow-elev-sm sm:h-[72px] sm:w-[72px]"
        />
        <h1 className="mt-5 text-headline-sm font-bold text-foreground sm:text-headline-md">
          {t("install_heading")}
        </h1>
        <p className="mt-3 max-w-xl text-body-md text-text-secondary">
          {t("install_subheading")}
        </p>
      </header>

      {/* The one thing this page exists to do. */}
      <Card className="mt-8 border-brand/20 bg-brand-subtle/40">
        <CardContent className="flex flex-col items-center gap-4 py-8 text-center">
          {finished ? (
            <>
              <span className="flex h-12 w-12 items-center justify-center rounded-full bg-success/15 text-success">
                <Check className="h-6 w-6" aria-hidden />
              </span>
              <div>
                <p className="text-title-md font-bold text-foreground">
                  {t(
                    install.standalone
                      ? "install_standalone_title"
                      : "install_installed_title",
                  )}
                </p>
                <p className="mt-1 text-body-sm text-text-secondary">
                  {t(
                    install.standalone
                      ? "install_standalone_body"
                      : "install_installed_body",
                  )}
                </p>
              </div>
              <Link
                href="/dashboard"
                className={buttonVariants({ variant: "outline" })}
              >
                {t("install_open_app")}
              </Link>
            </>
          ) : inDesktop ? (
            <>
              <span className="flex h-12 w-12 items-center justify-center rounded-full bg-brand/15 text-brand">
                <AppWindow className="h-6 w-6" aria-hidden />
              </span>
              <div>
                <p className="text-title-md font-bold text-foreground">
                  {t("install_desktop_title")}
                </p>
                <p className="mt-1 text-body-sm text-text-secondary">
                  {t("install_desktop_body")}
                </p>
              </div>
            </>
          ) : install.canPrompt ? (
            <>
              <Button size="lg" onClick={onInstall} disabled={busy}>
                {busy ? (
                  <Loader2 className="h-5 w-5 animate-spin" aria-hidden />
                ) : (
                  <Download className="h-5 w-5" aria-hidden />
                )}
                {busy ? t("install_working") : t("install_action")}
              </Button>
              <p className="text-body-sm text-text-secondary">
                {t("install_subheading")}
              </p>
            </>
          ) : !supported ? (
            /* Firefox on desktop, or a non-Safari browser on iOS: no install path
               exists, so the only useful thing is to move the visitor to one. */
            <>
              <span className="flex h-12 w-12 items-center justify-center rounded-full bg-warning/15 text-warning">
                <Info className="h-6 w-6" aria-hidden />
              </span>
              <div>
                <p className="text-title-md font-bold text-foreground">
                  {t("install_unsupported_title")}
                </p>
                <p className="mt-1 text-body-sm text-text-secondary">
                  {t(
                    env?.platform === "ios"
                      ? "install_unsupported_ios_body"
                      : "install_unsupported_body",
                  )}
                </p>
              </div>
              <Button variant="outline" onClick={onCopyLink}>
                <Link2 className="h-4 w-4" aria-hidden />
                {t("install_copy_link")}
              </Button>
            </>
          ) : (
            /* Installable, but the browser has not offered a prompt (already
               dismissed, or it only ever installs from its own menu). */
            <>
              <span className="flex h-12 w-12 items-center justify-center rounded-full bg-brand/15 text-brand">
                <Download className="h-6 w-6" aria-hidden />
              </span>
              <p className="text-body-md text-text-secondary">
                {t("install_steps_title")}
              </p>
            </>
          )}
        </CardContent>
      </Card>

      {!finished && !inDesktop && supported && steps.length > 0 && (
        <section className="mt-8">
          <h2 className="text-title-md font-bold text-foreground">
            {t("install_steps_title")}
          </h2>
          <ol className="mt-4 space-y-3">
            {steps.map((key, index) => (
              <li key={key} className="flex items-start gap-3">
                <span className="mt-0.5 flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-brand text-label-sm font-bold text-primary-foreground">
                  {index + 1}
                </span>
                <span className="text-body-md text-foreground">{t(key)}</span>
              </li>
            ))}
          </ol>
        </section>
      )}

      <section className="mt-10">
        <h2 className="text-title-md font-bold text-foreground">
          {t("install_why_title")}
        </h2>
        <div className="mt-4 grid gap-3 sm:grid-cols-3">
          {[
            {
              icon: LayoutGrid,
              title: "install_why_icon_title",
              body: "install_why_icon_body",
            },
            {
              icon: AppWindow,
              title: "install_why_window_title",
              body: "install_why_window_body",
            },
            {
              icon: ShieldCheck,
              title: "install_why_safe_title",
              body: "install_why_safe_body",
            },
          ].map(({ icon: Icon, title, body }) => (
            <Card key={title}>
              <CardContent className="py-5">
                <Icon className="h-5 w-5 text-brand" aria-hidden />
                <p className="mt-3 text-label-lg font-semibold text-foreground">
                  {t(title as TKey)}
                </p>
                <p className="mt-1 text-body-sm text-text-secondary">
                  {t(body as TKey)}
                </p>
              </CardContent>
            </Card>
          ))}
        </div>
      </section>

      <details className="group mt-8 rounded-xl border border-border bg-card px-4 py-3">
        <summary className="cursor-pointer list-none text-label-lg font-semibold text-foreground marker:content-['']">
          {t("install_other_title")}
        </summary>
        <div className="mt-4 space-y-5 border-t border-border pt-4">
          {OTHER_PLATFORMS.map(({ label, steps: otherSteps }) => (
            <div key={label}>
              <p className="text-label-md font-semibold text-text-secondary">
                {t(label)}
              </p>
              <ol className="mt-2 list-inside list-decimal space-y-1">
                {otherSteps.map((key) => (
                  <li key={key} className="text-body-sm text-foreground">
                    {t(key)}
                  </li>
                ))}
              </ol>
            </div>
          ))}
        </div>
      </details>

      <p className="mt-8 flex items-start gap-2 text-body-sm text-text-tertiary">
        <Info className="mt-0.5 h-4 w-4 shrink-0" aria-hidden />
        <span>
          <span className="font-semibold">{t("install_note_title")}: </span>
          {t("install_note_body")}
        </span>
      </p>
    </main>
  );
}
