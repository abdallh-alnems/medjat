"use client";

import { useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { useT } from "@/lib/i18n/use-t";
import {
  ApiError,
  checkIn,
  checkOut,
  fetchStatus,
  getPosition,
  logout,
  type WebStatus,
} from "@/features/employee-attendance/api";
import { usePunchPhoto } from "@/features/employee-attendance/use-punch-photo";

export default function EmployeeAttendancePage() {
  const { t, dir, locale } = useT();
  const router = useRouter();

  const [status, setStatus] = useState<WebStatus | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  const photoRequired = status?.photo_required ?? false;
  // Destructured at the call site: reading these off the hook result inside
  // JSX counts as touching a ref during render.
  const {
    videoRef,
    state: cameraState,
    start: startCamera,
    stop: stopCamera,
    capture: capturePhoto,
  } = usePunchPhoto(photoRequired);

  // `t` is deliberately NOT a dependency here. useT() returns a fresh object on
  // every render, so depending on it recreates this callback each time, which
  // re-runs the effect below, which sets state, which renders again — an
  // infinite fetch loop that hammered the endpoint at exactly the rate limit
  // until a browser test caught it. Errors are therefore stored as raw messages
  // and translated at render time instead.
  const load = useCallback(async () => {
    try {
      const next = await fetchStatus();
      setStatus(next);
      setError(null);
      return next;
    } catch (err) {
      if (err instanceof ApiError && err.status === 401) {
        router.replace("/me/login");
        return null;
      }
      setError(err instanceof ApiError ? err.message : "error");
      return null;
    } finally {
      setLoading(false);
    }
  }, [router]);

  // Both state updates happen inside the async callback rather than in the
  // effect body, so the effect only kicks off external work — which is what
  // effects are for. The camera is started from the same place, and only once
  // the server has said a photo is needed: turning it on speculatively would
  // light the indicator for employees whose company never asked for one.
  useEffect(() => {
    let cancelled = false;
    void (async () => {
      const next = await load();
      if (cancelled || !next) return;
      if (next.photo_required && next.state !== "checked_out") {
        void startCamera();
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [load, startCamera]);

  function describeError(err: unknown): string {
    if (!(err instanceof ApiError)) return t("error");
    switch (err.code) {
      case "GEO_DENIED":
        return t("emp_geo_denied");
      case "GEO_TIMEOUT":
        return t("emp_geo_timeout");
      case "GEO_UNSUPPORTED":
        return t("emp_geo_unsupported");
      case "GEO_UNAVAILABLE":
        return t("emp_geo_unavailable");
      default:
        return err.message || t("error");
    }
  }

  async function punch(kind: "in" | "out") {
    if (!status) return;
    setBusy(true);
    setError(null);
    setNotice(null);

    try {
      if (photoRequired && cameraState === "denied") {
        setError(t("emp_camera_denied"));
        return;
      }

      const position = await getPosition();
      const photo = photoRequired ? capturePhoto() ?? undefined : undefined;

      if (photoRequired && !photo) {
        setError(t("emp_camera_denied"));
        return;
      }

      if (kind === "in") {
        if (!status.branch) {
          setError(t("emp_no_branch"));
          return;
        }
        await checkIn({
          branch_id: status.branch.id,
          latitude: position.coords.latitude,
          longitude: position.coords.longitude,
          photo_base64: photo,
        });
        setNotice(t("emp_checked_in_ok"));
        await load();
      } else {
        const result = await checkOut({
          latitude: position.coords.latitude,
          longitude: position.coords.longitude,
          photo_base64: photo,
        });
        stopCamera();
        setNotice(t("emp_checked_out_ok"));
        // The server ends the session on check-out, so there is nothing left to
        // do here but leave. Staying on a page whose every call now 401s would
        // just look broken.
        if (result?.session_ended !== false) {
          setTimeout(() => router.replace("/me/login"), 1500);
          return;
        }
        await load();
      }
    } catch (err) {
      if (err instanceof ApiError && err.status === 401) {
        router.replace("/me/login");
        return;
      }
      // A request that failed in transit may or may not have been recorded.
      // Saying so and re-reading the truth is better than a confident "failed"
      // that leaves the employee punching twice.
      if (err instanceof ApiError && err.status === 502) {
        setError(t("emp_unknown_result"));
        await load();
        return;
      }
      setError(describeError(err));
    } finally {
      setBusy(false);
    }
  }

  async function signOut() {
    stopCamera();
    await logout();
    router.replace("/me/login");
  }

  if (loading) {
    return (
      <Card dir={dir}>
        <CardContent className="py-10 text-center text-muted-foreground">{t("loading")}</CardContent>
      </Card>
    );
  }

  const state = status?.state ?? "not_checked_in";

  // A check-in this employee's methods cannot produce. Withholding the button is
  // the honest move: pressing it reaches the server, is refused, and comes back
  // asking them to scan a QR code on a page that has no scanner. Left false while
  // the status is still loading, so an unanswered request never reads as blocked.
  const blocked = status ? !status.can_punch : false;

  const canCheckIn = state === "not_checked_in" && !blocked;

  // Check-out is NOT gated on it. Someone who checked in on their phone must
  // always be able to close the day, and check_out.php has no method gate for
  // exactly that reason — a control that can strand an employee clocked in is a
  // payroll problem wearing a security badge.
  const canCheckOut = state === "checked_in";

  // Times come from the server, formatted for display only. The device clock is
  // user-editable with no permission prompt, so it is never a source here.
  const fmt = (value: string | null) =>
    value ? value.slice(0, 5) : null;

  return (
    <Card dir={dir}>
      <CardHeader>
        <CardTitle>{t("emp_attendance_title")}</CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="rounded-lg bg-muted p-4 text-center">
          <p className="font-medium">
            {state === "checked_in" && t("emp_state_checked_in")}
            {state === "checked_out" && t("emp_state_checked_out")}
            {state === "not_checked_in" && t("emp_state_not_checked_in")}
          </p>
          {status?.check_in_at && (
            <p className="mt-1 text-sm text-muted-foreground">
              {t("emp_since")} <span dir="ltr">{fmt(status.check_in_at)}</span>
              {status.check_in_origin === "app" && ` · ${t("emp_recorded_from_app")}`}
            </p>
          )}
          {status?.branch && (
            <p className="mt-1 text-sm text-muted-foreground">{status.branch.name}</p>
          )}
        </div>

        {photoRequired && state !== "checked_out" && (
          <div className="space-y-2">
            {/* Told before the shutter, not after — consent that arrives late is not consent. */}
            <p className="text-xs text-muted-foreground">{t("emp_photo_notice")}</p>
            <video
              ref={videoRef}
              playsInline
              muted
              className="w-full rounded-lg bg-black"
              aria-label={t("emp_camera_needed")}
            />
            {cameraState === "denied" && (
              <p role="alert" className="text-sm text-destructive">
                {t("emp_camera_denied")}
              </p>
            )}
          </div>
        )}

        {/* Only where it is actionable: someone already checked in needs the
            check-out button below, not an explanation of why they cannot start
            a day they have already started. */}
        {blocked && state === "not_checked_in" && (
          <p
            role="alert"
            className="rounded-md border border-amber-500/40 bg-amber-500/5 p-3 text-sm"
          >
            {t("emp_blocked_gps_only")}
          </p>
        )}

        {notice && (
          <p role="status" className="text-sm text-primary">
            {notice}
          </p>
        )}
        {error && (
          <p role="alert" className="text-sm text-destructive">
            {error}
          </p>
        )}

        {canCheckIn && (
          <Button className="w-full" disabled={busy} onClick={() => punch("in")}>
            {busy ? t("emp_submitting") : t("emp_check_in")}
          </Button>
        )}
        {canCheckOut && (
          <Button className="w-full" variant="secondary" disabled={busy} onClick={() => punch("out")}>
            {busy ? t("emp_submitting") : t("emp_check_out")}
          </Button>
        )}

        <Button variant="ghost" className="w-full" onClick={signOut} disabled={busy}>
          {t("emp_sign_out")}
        </Button>

        <p className="text-center text-[11px] text-muted-foreground" dir="ltr">
          {status?.server_time
            ? new Date(status.server_time).toLocaleString(locale === "ar" ? "ar-EG" : "en-GB")
            : null}
        </p>
      </CardContent>
    </Card>
  );
}
