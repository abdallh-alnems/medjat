"use client";

import { useMemo, useState } from "react";
import { useT } from "@/lib/i18n/use-t";
import {
  useBranchNetworks,
  useApproveBranchNetworks,
} from "@/lib/hooks/use-settings";
import type { AttendanceBranchOverride } from "@/lib/api/settings";
import { LoadingState, ErrorState } from "@/components/ui/states";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Checkbox } from "@/components/ui/checkbox";
import { Badge } from "@/components/ui/badge";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
  DialogClose,
} from "@/components/ui/dialog";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

type WifiMode = "learning" | "enforcing" | "optional";

/**
 * Approval screen for a branch's WiFi access points.
 *
 * The whole point is the coverage figure: it answers "if I approve exactly
 * these and switch to enforcing, what share of last week's check-ins would
 * still pass?" — before the switch is flipped, rather than from a queue of
 * complaints the next morning.
 */
export function BranchNetworksDialog({
  branch,
  open,
  onOpenChange,
}: {
  branch: AttendanceBranchOverride | null;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}) {
  const { t } = useT();
  const { data, isLoading, isError, refetch } = useBranchNetworks(
    open && branch ? branch.id : null,
  );
  const save = useApproveBranchNetworks();

  // null until the report loads, then seeded from what is already approved.
  const [selected, setSelected] = useState<Set<string> | null>(null);
  const [mode, setMode] = useState<WifiMode | null>(null);

  const rows = useMemo(() => data?.networks ?? [], [data?.networks]);
  const effectiveSelected = useMemo(() => {
    if (selected) return selected;
    return new Set(rows.filter((n) => n.is_approved).map((n) => n.bssid));
  }, [selected, rows]);

  const effectiveMode: WifiMode = mode ?? data?.wifi_mode ?? "learning";

  // Recomputed live as boxes are ticked, so the warning tracks the real choice.
  const coverage = useMemo(() => {
    const total = data?.total_sightings ?? 0;
    if (total === 0) return 0;
    const covered = rows
      .filter((n) => effectiveSelected.has(n.bssid))
      .reduce((sum, n) => sum + n.sightings, 0);
    return Math.round((covered / total) * 1000) / 10;
  }, [rows, effectiveSelected, data?.total_sightings]);

  const toggle = (bssid: string) => {
    const next = new Set(effectiveSelected);
    if (next.has(bssid)) next.delete(bssid);
    else next.add(bssid);
    setSelected(next);
  };

  const willEnforce = effectiveMode === "enforcing";
  const lowCoverage = willEnforce && coverage < 90 && (data?.total_sightings ?? 0) > 0;
  const noneSelected = effectiveSelected.size === 0;

  const submit = () => {
    if (!branch) return;
    save.mutate(
      {
        branch_id: branch.id,
        approve: rows
          .filter((n) => effectiveSelected.has(n.bssid))
          .map((n) => ({
            kind: "bssid" as const,
            value: n.bssid,
            label: n.ssid ?? undefined,
          })),
        deactivate: [],
        wifi_mode: effectiveMode,
      },
      {
        onSuccess: () => {
          setSelected(null);
          setMode(null);
          onOpenChange(false);
        },
      },
    );
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[85vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>
            {t("wifi_networks")}
            {branch ? ` — ${branch.name}` : ""}
          </DialogTitle>
        </DialogHeader>

        {isLoading ? (
          <LoadingState />
        ) : isError || !data ? (
          <ErrorState onRetry={() => refetch()} />
        ) : (
          <div className="space-y-4">
            <p className="text-body-md text-muted-foreground">
              {t("wifi_networks_hint")}
            </p>

            {/* ── Mode ── */}
            <div className="space-y-1.5">
              <Label>{t("wifi_mode")}</Label>
              <Select
                value={effectiveMode}
                onValueChange={(v) => v && setMode(v as WifiMode)}
              >
                <SelectTrigger className="w-full">
                  <SelectValue>
                    {() => t(`wifi_mode_${effectiveMode}` as never)}
                  </SelectValue>
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="learning">
                    {t("wifi_mode_learning")}
                  </SelectItem>
                  <SelectItem value="enforcing">
                    {t("wifi_mode_enforcing")}
                  </SelectItem>
                  <SelectItem value="optional">
                    {t("wifi_mode_optional")}
                  </SelectItem>
                </SelectContent>
              </Select>
              <p className="text-xs text-muted-foreground">
                {t("wifi_mode_hint")}
              </p>
            </div>

            {/* ── Sightings ── */}
            <div className="space-y-2">
              <Label>{t("wifi_seen_networks")}</Label>
              {rows.length === 0 ? (
                <p className="text-body-md text-muted-foreground">
                  {t("wifi_no_sightings")}
                </p>
              ) : (
                rows.map((n) => (
                  <label
                    key={n.bssid}
                    className="flex items-start gap-3 rounded-lg border p-3"
                  >
                    <Checkbox
                      checked={effectiveSelected.has(n.bssid)}
                      onCheckedChange={() => toggle(n.bssid)}
                      className="mt-0.5"
                    />
                    <div className="min-w-0 flex-1">
                      <div className="flex flex-wrap items-center gap-2">
                        <span className="font-medium">
                          {n.ssid ?? t("wifi_gps")}
                        </span>
                        <code className="text-xs text-muted-foreground">
                          {n.bssid}
                        </code>
                      </div>
                      <div className="mt-1 flex flex-wrap items-center gap-2 text-body-md text-muted-foreground">
                        <span>
                          {t("wifi_sightings_count").replace(
                            "@count",
                            String(n.sightings),
                          )}
                        </span>
                        {n.all_inside ? (
                          <Badge variant="secondary">{t("wifi_all_inside")}</Badge>
                        ) : n.all_outside ? (
                          <Badge variant="destructive">
                            {t("wifi_all_outside")}
                          </Badge>
                        ) : (
                          <span>
                            {t("wifi_mixed_location")
                              .replace("@inside", String(n.inside_count))
                              .replace("@outside", String(n.outside_count))}
                          </span>
                        )}
                      </div>
                      {n.all_outside && (
                        <p className="mt-1 text-xs text-destructive">
                          {t("wifi_outside_hint")}
                        </p>
                      )}
                    </div>
                  </label>
                ))
              )}
            </div>

            {/* ── Coverage ── */}
            {(data.total_sightings ?? 0) > 0 && (
              <div className="rounded-lg border p-3">
                <div className="flex items-center justify-between gap-2">
                  <span className="font-medium">{t("wifi_coverage")}</span>
                  <span
                    className={`font-mono tabular-nums ${
                      lowCoverage ? "text-destructive" : ""
                    }`}
                  >
                    {coverage}%
                  </span>
                </div>
                {lowCoverage && (
                  <p className="mt-1 text-xs text-destructive">
                    {t("wifi_coverage_warning").replace(
                      "@percent",
                      String(Math.round((100 - coverage) * 10) / 10),
                    )}
                  </p>
                )}
              </div>
            )}

            {willEnforce && noneSelected && (
              <p className="text-xs text-destructive">
                {t("wifi_needs_one_network")}
              </p>
            )}
          </div>
        )}

        <DialogFooter>
          <DialogClose render={<Button variant="outline" />}>
            {t("cancel")}
          </DialogClose>
          <Button
            disabled={save.isPending || (willEnforce && noneSelected)}
            onClick={submit}
          >
            {save.isPending
              ? t("saving")
              : willEnforce
                ? t("wifi_save_and_enforce")
                : t("wifi_save_selection")}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
