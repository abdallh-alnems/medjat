"use client";

/**
 * The screen that lives at a branch door.
 *
 * It shows a QR code that changes every `rotate_in` seconds. Employees scan
 * whatever is on it; the server accepts each code once per employee, so a
 * photograph forwarded to a colleague is worthless by the time it arrives.
 *
 * Two things drive the design, and both come from where this runs — a cheap
 * tablet propped up in a doorway, read from one to three metres away by someone
 * who is not going to troubleshoot it:
 *
 *   1) The QR must be large and high-contrast. Everything else on the page is
 *      subordinate to it.
 *   2) A failure must be visible from across the room. A display that quietly
 *      stops refreshing looks exactly like one that is working, and the queue at
 *      the door is how you find out. So a stale code says so, loudly.
 */

import { useEffect, useState } from "react";
import QRCode from "qrcode";
import { useT } from "@/lib/i18n/use-t";
import { useBranches } from "@/lib/hooks/use-org";
import { fetchBranchRotatingQr, type RotatingQrCode } from "@/lib/api/branches";
import { LoadingState } from "@/components/ui/states";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

/** Rendered size of the QR bitmap. Large enough to scan across a doorway. */
const QR_PIXELS = 720;

/**
 * How long after a code should have rotated before the screen calls itself
 * broken. One missed refresh is a blip; two means nobody is getting in.
 */
const STALE_GRACE_SECONDS = 8;

/** Retry sooner than a normal rotation so a brief network blip self-heals. */
const RETRY_MS = 5000;

export default function BranchQrDisplayPage() {
  const { t } = useT();
  const branches = useBranches();
  const [chosen, setChosen] = useState<number | null>(null);

  const rotating = (branches.data ?? []).filter(
    (b) => (b as { rotating_qr_enabled?: number }).rotating_qr_enabled === 1,
  );

  // Derived, not stored via an effect: the common case is one screen at one
  // door, and asking that user to pick from a list of one is friction for
  // nothing. Computing it keeps the auto-selection out of render-triggering
  // state entirely.
  const branchId = chosen ?? (rotating.length === 1 ? rotating[0].id : null);

  if (branches.isLoading) return <LoadingState />;

  if (rotating.length === 0) {
    return (
      <div className="p-6">
        <p className="text-body-md text-muted-foreground">
          {t("rotating_qr_no_branches")}
        </p>
      </div>
    );
  }

  if (branchId === null) {
    return (
      <div className="max-w-sm space-y-3 p-6">
        <p className="text-body-md">{t("rotating_qr_pick_branch")}</p>
        <Select onValueChange={(v) => setChosen(Number(v))}>
          <SelectTrigger>
            <SelectValue placeholder={t("branch")} />
          </SelectTrigger>
          <SelectContent>
            {rotating.map((b) => (
              <SelectItem key={b.id} value={String(b.id)}>
                {b.name}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>
    );
  }

  return <Display branchId={branchId} />;
}

function Display({ branchId }: { branchId: number }) {
  const { t } = useT();
  const [code, setCode] = useState<RotatingQrCode | null>(null);
  const [dataUrl, setDataUrl] = useState<string | null>(null);
  const [stale, setStale] = useState(false);

  // The whole polling loop lives inside the effect so its timers cannot outlive
  // it. `tick` is a function declaration rather than a const arrow so it can
  // schedule itself without being referenced before it is defined.
  useEffect(() => {
    let cancelled = false;
    let rotateTimer: ReturnType<typeof setTimeout> | null = null;
    let staleTimer: ReturnType<typeof setTimeout> | null = null;

    async function tick() {
      try {
        const next = await fetchBranchRotatingQr(branchId);

        // Render the image locally. Asking the server for a picture would put a
        // live credential through a cache nobody here controls.
        const png = await QRCode.toDataURL(next.nonce, {
          width: QR_PIXELS,
          margin: 1,
          errorCorrectionLevel: "M",
        });

        if (cancelled) return;

        setCode(next);
        setDataUrl(png);
        setStale(false);

        if (staleTimer) clearTimeout(staleTimer);
        staleTimer = setTimeout(
          () => setStale(true),
          (next.rotate_in + STALE_GRACE_SECONDS) * 1000,
        );

        rotateTimer = setTimeout(tick, next.rotate_in * 1000);
      } catch {
        // Keep whatever is already on screen: it may still be inside its TTL,
        // and a blank wall helps nobody. The stale overlay is what tells the
        // room when that stops being true.
        if (cancelled) return;
        rotateTimer = setTimeout(tick, RETRY_MS);
      }
    }

    void tick();

    return () => {
      cancelled = true;
      if (rotateTimer) clearTimeout(rotateTimer);
      if (staleTimer) clearTimeout(staleTimer);
    };
  }, [branchId]);

  if (!dataUrl) return <LoadingState />;

  return (
    <div className="flex min-h-[80vh] flex-col items-center justify-center gap-6 p-4">
      <h1 className="text-center text-2xl font-semibold">
        {code?.branch ?? ""}
      </h1>

      <div className="relative">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={dataUrl}
          alt={t("rotating_qr_alt")}
          className="h-auto w-full max-w-[min(80vw,720px)] rounded-lg bg-white p-4"
          style={{ imageRendering: "pixelated" }}
        />
        {stale && (
          <div className="absolute inset-0 flex items-center justify-center rounded-lg bg-black/70 p-4">
            <p className="text-center text-xl font-semibold text-white">
              {t("rotating_qr_stale")}
            </p>
          </div>
        )}
      </div>

      <p className="max-w-md text-center text-body-md text-muted-foreground">
        {t("rotating_qr_instruction")}
      </p>
    </div>
  );
}
