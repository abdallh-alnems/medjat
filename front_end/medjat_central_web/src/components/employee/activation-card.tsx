"use client";

import { useEffect, useState } from "react";
import QRCode from "qrcode";
import { useQuery } from "@tanstack/react-query";
import { toast } from "sonner";
import { useT } from "@/lib/i18n/use-t";
import { useUIStore } from "@/lib/stores/ui-store";
import { useToastMutation } from "@/lib/hooks/use-org";
import {
  getActivationCode,
  regenerateActivationCode,
} from "@/lib/api/employees";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
  DialogClose,
} from "@/components/ui/dialog";
import { formatDate } from "@/lib/utils";
import { Copy, RefreshCw, Smartphone } from "lucide-react";

/** Activation code / join link / QR / bound-device management for an employee. */
export function ActivationCard({ employeeId }: { employeeId: number }) {
  const { t } = useT();
  const locale = useUIStore((s) => s.locale);
  const [qr, setQr] = useState<string>("");
  const [confirmOpen, setConfirmOpen] = useState(false);

  const { data, isLoading, refetch } = useQuery({
    queryKey: ["activation", employeeId],
    queryFn: () => getActivationCode(employeeId),
  });

  const regen = useToastMutation(() => regenerateActivationCode(employeeId), {
    successMessage: t("code_regenerated"),
    onSuccess: () => {
      setConfirmOpen(false);
      refetch();
    },
  });

  const joinLink = data?.join_link ?? "";
  useEffect(() => {
    let active = true;
    const set = (v: string) => {
      if (active) setQr(v);
    };
    if (joinLink) {
      QRCode.toDataURL(joinLink, { width: 240, margin: 2 })
        .then(set)
        .catch(() => set(""));
    } else {
      Promise.resolve().then(() => set(""));
    }
    return () => {
      active = false;
    };
  }, [joinLink]);

  const copy = (text: string | null | undefined, msg: string) => {
    if (!text) return;
    navigator.clipboard
      .writeText(text)
      .then(() => toast.success(t(msg as never)))
      .catch(() => {});
  };

  const code = data?.activation_code ?? null;
  const deviceBound = data?.device_bound ?? false;
  // Regenerating for a bound/active employee resets their device → confirm.
  const needsConfirm = deviceBound || data?.employee_status === "active";

  const onRegenerate = () => {
    if (needsConfirm) setConfirmOpen(true);
    else regen.mutate(undefined);
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-title-lg">{t("employee_activation")}</CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        {isLoading ? (
          <div className="h-40 animate-pulse rounded-lg bg-muted" />
        ) : code ? (
          <>
            <p className="text-body-md text-muted-foreground">
              {t("send_code_hint")}
            </p>

            <div className="flex flex-col gap-4 sm:flex-row sm:items-center">
              {qr ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  src={qr}
                  alt={t("join_qr")}
                  className="h-40 w-40 rounded-lg border bg-white p-2"
                />
              ) : (
                <div className="h-40 w-40 animate-pulse rounded-lg bg-muted" />
              )}

              <div className="flex-1 space-y-3">
                <div>
                  <p className="text-label-sm text-muted-foreground">
                    {t("activation_code")}
                  </p>
                  <div className="flex items-center gap-2">
                    <span className="font-mono text-headline-sm font-bold tracking-widest">
                      {code}
                    </span>
                    <Button
                      variant="ghost"
                      size="icon-sm"
                      onClick={() => copy(code, "code_copied")}
                    >
                      <Copy className="h-4 w-4" />
                    </Button>
                  </div>
                  {data?.expires_at && (
                    <p className="text-label-sm text-muted-foreground">
                      {t("expiry")}: {formatDate(data.expires_at, locale)}
                    </p>
                  )}
                </div>

                {joinLink && (
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => copy(joinLink, "link_copied")}
                  >
                    <Copy className="h-4 w-4" />
                    {t("copy_link")}
                  </Button>
                )}
              </div>
            </div>
          </>
        ) : (
          <p className="text-body-md text-muted-foreground">
            {t("no_active_code")}
          </p>
        )}

        {/* Bound device */}
        <div className="rounded-lg border p-3">
          <p className="flex items-center gap-2 text-label-sm text-muted-foreground">
            <Smartphone className="h-4 w-4" />
            {t("device_bound_title")}
          </p>
          {deviceBound && data?.device ? (
            <div className="mt-1">
              <p className="font-medium">
                {data.device.device_model ?? "—"}
                {data.device.platform ? (
                  <Badge variant="secondary" className="ms-2">
                    {data.device.platform}
                  </Badge>
                ) : null}
              </p>
              {data.device.last_used_at && (
                <p className="text-label-sm text-muted-foreground">
                  {t("device_last_seen")}:{" "}
                  {formatDate(data.device.last_used_at, locale)}
                </p>
              )}
            </div>
          ) : (
            <p className="mt-1 text-body-md text-muted-foreground">
              {t("no_device_bound")}
            </p>
          )}
        </div>

        <Button
          variant="outline"
          size="sm"
          disabled={regen.isPending}
          onClick={onRegenerate}
        >
          <RefreshCw className="h-4 w-4" />
          {code ? t("regenerate_code") : t("generate_activation_code")}
        </Button>
      </CardContent>

      <Dialog open={confirmOpen} onOpenChange={setConfirmOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{t("reset_device_title")}</DialogTitle>
            <DialogDescription>{t("reset_device_warning")}</DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <DialogClose render={<Button variant="outline" />}>
              {t("cancel")}
            </DialogClose>
            <Button
              variant="destructive"
              disabled={regen.isPending}
              onClick={() => regen.mutate(undefined)}
            >
              {regen.isPending ? t("saving") : t("regenerate_code")}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </Card>
  );
}
