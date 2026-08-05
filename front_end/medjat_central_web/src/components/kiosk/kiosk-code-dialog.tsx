"use client";

import { useT } from "@/lib/i18n/use-t";
import { Button } from "@/components/ui/button";
import { Copy, X } from "lucide-react";

/**
 * Shows a code that exists exactly once.
 *
 * Both kiosk codes are returned in plaintext by the server and stored only as
 * hashes, so there is no second chance to read one. The dialog is deliberately
 * blunt about that, and offers a copy button rather than expecting anyone to
 * transcribe eight characters correctly from a laptop onto a wall-mounted
 * tablet.
 */
export function KioskCodeDialog({
  code,
  title,
  explanation,
  onClose,
}: {
  code: string;
  title: string;
  explanation: string;
  onClose: () => void;
}) {
  const { t } = useT();

  return (
    // No click-outside-to-dismiss: losing this by a stray click means issuing
    // a new code.
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <div className="bg-background w-full max-w-sm rounded-xl p-6 shadow-lg">
        <div className="mb-4 flex items-center justify-between">
          <h2 className="font-semibold">{title}</h2>
          <button
            onClick={onClose}
            aria-label={t("close")}
            className="text-muted-foreground hover:text-foreground"
          >
            <X className="size-4" />
          </button>
        </div>

        <div className="bg-primary/10 text-primary rounded-lg py-6 text-center">
          <span className="font-mono text-3xl font-bold tracking-[0.3em]">
            {code}
          </span>
        </div>

        <p className="text-muted-foreground mt-4 text-center text-sm">
          {explanation}
        </p>
        <p className="mt-2 text-center text-xs text-amber-600">
          {t("kiosk_code_once")}
        </p>

        <div className="mt-5 flex gap-2">
          <Button
            variant="outline"
            className="flex-1"
            onClick={() => navigator.clipboard.writeText(code)}
          >
            <Copy className="size-4" />
            {t("copy")}
          </Button>
          <Button className="flex-1" onClick={onClose}>
            {t("done")}
          </Button>
        </div>
      </div>
    </div>
  );
}
