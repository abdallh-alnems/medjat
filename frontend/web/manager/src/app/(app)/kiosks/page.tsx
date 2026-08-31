"use client";

import { useState } from "react";
import { useT } from "@/lib/i18n/use-t";
import { usePermissions } from "@/lib/hooks/use-permissions";
import { useBranches } from "@/lib/hooks/use-org";
import {
  useCreateKioskAccessCode,
  useCreateKioskPairingCode,
  useKiosks,
  useRevokeKiosk,
} from "@/lib/hooks/use-kiosks";
import { LoadingState, ErrorState, EmptyState } from "@/components/ui/states";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { KioskCodeDialog } from "@/components/kiosk/kiosk-code-dialog";
import { Tablet, Plus, AlertTriangle, WifiOff } from "lucide-react";
import type { Branch } from "@/lib/types";

/**
 * Branch kiosks.
 *
 * The only route into putting a tablet into service: a kiosk cannot pair
 * without a code, and a code cannot exist without an administrator asking for
 * one here.
 */
export default function KiosksPage() {
  const { t } = useT();
  const { can } = usePermissions();
  const { data, isLoading, isError, refetch } = useKiosks();
  const { data: branches } = useBranches();

  const canManage = can("kiosk_devices");
  const canAccess = can("kiosk_access");

  const pairingCode = useCreateKioskPairingCode();
  const accessCode = useCreateKioskAccessCode();
  const revoke = useRevokeKiosk();

  const [dialog, setDialog] = useState<
    { code: string; title: string; explanation: string } | null
  >(null);
  const [adding, setAdding] = useState(false);
  const [branchId, setBranchId] = useState<number | null>(null);
  const [name, setName] = useState("");

  if (isLoading) return <LoadingState />;
  if (isError) return <ErrorState onRetry={refetch} />;

  const stations = data?.stations ?? [];
  const rosters = data?.rosters ?? [];
  const overCeiling = rosters.filter((r) => r.over_ceiling);

  async function createPairing() {
    if (!branchId) return;
    const result = await pairingCode.mutateAsync({ branchId, name });
    setAdding(false);
    setName("");
    // Shown once: the server keeps only a hash of it.
    setDialog({
      code: result.code,
      title: t("kiosk_pairing_code"),
      explanation: t("kiosk_pairing_code_hint"),
    });
    refetch();
  }

  async function openSettings(stationId: number) {
    const result = await accessCode.mutateAsync(stationId);
    setDialog({
      code: result.code,
      title: t("kiosk_access_code"),
      explanation: t("kiosk_access_code_hint"),
    });
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between gap-2">
        <h1 className="text-lg font-semibold">{t("kiosks")}</h1>
        {canManage && (
          <Button onClick={() => setAdding((v) => !v)}>
            <Plus className="size-4" />
            {t("kiosk_add")}
          </Button>
        )}
      </div>

      {/* Raising the minimum version has a consequence that is invisible
          otherwise: a directly-installed kiosk has no store to update from, so
          somebody must physically visit each branch. */}
      {(data?.would_block_count ?? 0) > 0 && (
        <Card className="border-amber-400/40 bg-amber-50 dark:bg-amber-950/20">
          <CardContent className="flex items-start gap-3 p-4 text-sm">
            <AlertTriangle className="mt-0.5 size-4 shrink-0 text-amber-600" />
            <div>
              <p className="font-medium">{t("kiosk_version_warning_title")}</p>
              <p className="text-muted-foreground">
                {t("kiosk_version_warning_body").replace(
                  "@n",
                  String(data?.would_block_count),
                )}
              </p>
            </div>
          </CardContent>
        </Card>
      )}

      {overCeiling.map((r) => (
        <Card
          key={r.branch_id}
          className="border-amber-400/40 bg-amber-50 dark:bg-amber-950/20"
        >
          <CardContent className="flex items-start gap-3 p-4 text-sm">
            <AlertTriangle className="mt-0.5 size-4 shrink-0 text-amber-600" />
            <div>
              <p className="font-medium">{t("kiosk_roster_warning_title")}</p>
              <p className="text-muted-foreground">
                {t("kiosk_roster_warning_body")
                  .replace("@branch", r.branch_name)
                  .replace("@n", String(r.enrolled))
                  .replace("@max", String(r.warn_above))}
              </p>
            </div>
          </CardContent>
        </Card>
      ))}

      {adding && canManage && (
        <Card>
          <CardContent className="space-y-3 p-4">
            <div className="space-y-1.5">
              <Label>{t("branch")}</Label>
              <select
                className="border-input bg-background h-9 w-full rounded-md border px-3 text-sm"
                value={branchId ?? ""}
                onChange={(e) => setBranchId(Number(e.target.value) || null)}
              >
                <option value="">—</option>
                {(branches as Branch[] | undefined)?.map((b) => (
                  <option key={b.id} value={b.id}>
                    {b.name}
                  </option>
                ))}
              </select>
            </div>
            <div className="space-y-1.5">
              <Label>{t("kiosk_name")}</Label>
              <Input
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder={t("kiosk_name_hint")}
              />
            </div>
            <Button
              onClick={createPairing}
              disabled={!branchId || pairingCode.isPending}
            >
              {t("kiosk_generate_code")}
            </Button>
          </CardContent>
        </Card>
      )}

      {stations.length === 0 ? (
        <EmptyState
          message={t(canManage ? "kiosk_empty" : "kiosk_empty_no_permission")}
          icon={Tablet}
        />
      ) : (
        <div className="space-y-2">
          {stations.map((s) => {
            const revoked = s.status !== "active";
            return (
              <Card key={s.id}>
                <CardContent className="flex items-center gap-3 p-4">
                  <Tablet
                    className={
                      revoked
                        ? "size-5 text-muted-foreground"
                        : s.is_offline
                          ? "size-5 text-amber-600"
                          : "size-5 text-primary"
                    }
                  />
                  <div className="min-w-0 flex-1">
                    <p className="truncate font-medium">{s.name}</p>
                    <p className="text-muted-foreground truncate text-xs">
                      {[
                        s.branch.name,
                        revoked ? t("kiosk_revoked") : null,
                        s.is_offline && !revoked ? t("kiosk_is_offline") : null,
                        s.below_min_version ? t("kiosk_outdated") : null,
                        `v${s.app_version ?? "—"}`,
                        t("kiosk_punches").replace("@n", String(s.punch_count)),
                      ]
                        .filter(Boolean)
                        .join(" · ")}
                    </p>
                  </div>
                  {s.is_offline && !revoked && (
                    <WifiOff className="size-4 text-amber-600" />
                  )}
                  {!revoked && canAccess && (
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => openSettings(s.id)}
                      disabled={accessCode.isPending}
                    >
                      {t("kiosk_open_settings")}
                    </Button>
                  )}
                  {!revoked && canManage && (
                    <Button
                      variant="destructive"
                      size="sm"
                      onClick={() => {
                        if (confirm(t("kiosk_revoke_confirm"))) {
                          revoke.mutate({ stationId: s.id });
                        }
                      }}
                    >
                      {t("kiosk_revoke_action")}
                    </Button>
                  )}
                </CardContent>
              </Card>
            );
          })}
        </div>
      )}

      {dialog && (
        <KioskCodeDialog
          code={dialog.code}
          title={dialog.title}
          explanation={dialog.explanation}
          onClose={() => setDialog(null)}
        />
      )}
    </div>
  );
}
