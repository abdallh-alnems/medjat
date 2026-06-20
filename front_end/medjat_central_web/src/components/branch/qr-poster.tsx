"use client";

import { useEffect, useState } from "react";
import QRCode from "qrcode";
import { Button } from "@/components/ui/button";
import { useT } from "@/lib/i18n/use-t";

interface Props {
  branchName: string;
  token: string;
}

/** Branch QR poster (printable). Renders the QR for a branch check-in token. */
export function QrPoster({ branchName, token }: Props) {
  const { t } = useT();
  const [dataUrl, setDataUrl] = useState<string>("");

  useEffect(() => {
    QRCode.toDataURL(token, { width: 320, margin: 2 }).then(setDataUrl).catch(() => setDataUrl(""));
  }, [token]);

  return (
    <div className="flex flex-col items-center gap-4 rounded-xl border bg-card p-8 print:border-0 print:p-0">
      <h2 className="text-headline-md font-bold">{branchName}</h2>
      <p className="text-body-md text-muted-foreground">{t("qr_poster")}</p>
      {dataUrl ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img src={dataUrl} alt="QR" className="h-64 w-64" />
      ) : (
        <div className="h-64 w-64 animate-pulse rounded-lg bg-muted" />
      )}
      <Button variant="outline" onClick={() => window.print()}>
        {t("print_qr")}
      </Button>
    </div>
  );
}
