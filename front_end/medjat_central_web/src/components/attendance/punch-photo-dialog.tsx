"use client";

/**
 * Shows the image captured at a browser punch, loaded only when asked for.
 *
 * Evidence for a human, never a verdict: the photo is not scored, not matched
 * against an enrolled face, and its presence or absence decides nothing. It is
 * here so a manager who disputes a day can look at who pressed the button.
 * Loading on demand also means a day's review does not pull down a hundred
 * photographs of employees nobody asked about.
 */

import { useEffect, useState } from "react";
import { Camera } from "lucide-react";
import { fetchPunchPhoto } from "@/lib/api/attendance";
import { useT } from "@/lib/i18n/use-t";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";

export function PunchPhotoButton({
  attendanceId,
  which,
  label,
}: {
  attendanceId: number;
  which: "check_in" | "check_out";
  label: string;
}) {
  const { t } = useT();
  const [open, setOpen] = useState(false);
  const [url, setUrl] = useState<string | null>(null);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    if (!open || url || failed) return;
    let revoked = false;
    fetchPunchPhoto(attendanceId, which)
      .then((u) => {
        if (revoked) {
          URL.revokeObjectURL(u);
          return;
        }
        setUrl(u);
      })
      .catch(() => setFailed(true));
    return () => {
      revoked = true;
    };
  }, [open, url, failed, attendanceId, which]);

  // Object URLs are revoked on unmount, not on close: reopening the same photo
  // should not refetch it, and a revoked URL renders as a broken image.
  useEffect(() => {
    return () => {
      if (url) URL.revokeObjectURL(url);
    };
  }, [url]);

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger
        className="inline-flex items-center gap-1 text-body-sm underline"
        aria-label={`${t("punch_photo")} — ${label}`}
      >
        <Camera className="size-3.5" />
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>
            {t("punch_photo")} — {label}
          </DialogTitle>
        </DialogHeader>
        {failed ? (
          <p className="text-body-md text-muted-foreground">{t("error")}</p>
        ) : url ? (
          // eslint-disable-next-line @next/next/no-img-element -- blob URL, not a remote asset
          <img
            src={url}
            alt={`${t("punch_photo")} — ${label}`}
            className="max-h-[70vh] w-full rounded-md object-contain"
          />
        ) : (
          <div className="h-64 w-full animate-pulse rounded-md bg-foreground/10" />
        )}
      </DialogContent>
    </Dialog>
  );
}
