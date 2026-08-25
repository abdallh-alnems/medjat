"use client";

import { useState } from "react";
import { useT } from "@/lib/i18n/use-t";
import {
  useAttendanceMethodConfig,
  useUpdateAttendanceConfig,
  useSetCompanyGeofence,
  useUpdateBranchAttendanceConfig,
  useSetScopeMethodOverride,
  useUpdateFaceSettings,
} from "@/lib/hooks/use-settings";
import { useAdmins } from "@/lib/hooks/use-managers";
import { useEmployees } from "@/lib/hooks/use-employees";
import type { AttendanceMethod } from "@/lib/types";
import type { TKey } from "@/lib/i18n/ar";
import type {
  AttendanceMethodConfig,
  AttendanceBranchOverride,
  AttendanceCategoryOverride,
  AttendanceEmployeeOverride,
} from "@/lib/api/settings";
import { LoadingState, ErrorState } from "@/components/ui/states";
import { BranchNetworksDialog } from "@/components/settings/branch-networks-dialog";
import { WebAttendanceCard } from "@/components/settings/web-attendance-card";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
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

// A display list, not a whitelist: toggleMethod edits whatever the server sent,
// so a method absent here is hidden but never stripped from the company's
// configuration. 'device' and 'kiosk' are omitted deliberately — neither is a
// self-service method and both are configured from their own screens.
//
// 'crew_gps' is here because this is the only screen in the product that can set
// it. It is not self-service either — a supervisor records it FOR their crew —
// but it has no screen of its own, so leaving it out left it configurable
// nowhere at all.
const METHODS: AttendanceMethod[] = [
  "qr_gps",
  "gps_only",
  "face_selfie",
  "photo_gps",
  "wifi_gps",
  "crew_gps",
  "manual",
];

function methodLabels(
  t: (k: TKey) => string,
  methods: AttendanceMethod[] | null,
): string {
  if (!methods || methods.length === 0) return t("inherit_company");
  return methods.map((m) => t(m as TKey)).join("، ");
}

export default function AttendanceMethodPage() {
  const { data, isLoading, isError, refetch } = useAttendanceMethodConfig();
  if (isLoading) return <LoadingState />;
  if (isError || !data) return <ErrorState onRetry={() => refetch()} />;
  return <Editor config={data} />;
}

function Editor({ config }: { config: AttendanceMethodConfig }) {
  const { t } = useT();
  const updateConfig = useUpdateAttendanceConfig();
  const setGeofence = useSetCompanyGeofence();
  const admins = useAdmins();

  const methods = config.attendance_methods ?? [];
  const manualEnabled = methods.includes("manual");
  const faceEnabled = methods.includes("face_selfie");
  const manualIds = config.manual_attendance_admin_ids ?? [];

  const saveTenant = (
    patch: Partial<Parameters<typeof updateConfig.mutate>[0]>,
  ) =>
    updateConfig.mutate({
      attendance_methods: methods,
      manual_attendance_admin_ids: config.manual_attendance_admin_ids,
      allow_offline_attendance: config.allow_offline_attendance,
      reject_mock_location: config.reject_mock_location,
      ...patch,
    });

  const toggleMethod = (m: AttendanceMethod) => {
    const has = methods.includes(m);
    if (has && methods.length <= 1) return; // keep at least one
    const next = has ? methods.filter((x) => x !== m) : [...methods, m];
    saveTenant({ attendance_methods: next });
  };

  const toggleManualAdmin = (id: number) => {
    const next = manualIds.includes(id)
      ? manualIds.filter((x) => x !== id)
      : [...manualIds, id];
    saveTenant({ manual_attendance_admin_ids: next.length ? next : null });
  };

  const adminList = (Array.isArray(admins.data) ? admins.data : []).filter(
    (a) => a.is_active,
  );

  return (
    <div className="mx-auto max-w-3xl space-y-4">
      <div>
        <h1 className="text-headline-md font-bold">
          {t("attendance_method_settings")}
        </h1>
        <p className="mt-1 text-body-md text-muted-foreground">
          {t("attendance_method_intro")}
        </p>
      </div>

      {/* ── Company defaults ── */}
      <Card>
        <CardHeader>
          <CardTitle>{t("company_default_methods")}</CardTitle>
        </CardHeader>
        <CardContent className="space-y-3">
          <p className="text-body-md text-muted-foreground">
            {t("company_methods_hint")}
          </p>
          <div className="space-y-2">
            {METHODS.map((m) => {
              const checked = methods.includes(m);
              const isLast = checked && methods.length <= 1;
              return (
                <label key={m} className="flex items-center gap-2 text-body-md">
                  <Checkbox
                    checked={checked}
                    disabled={isLast || updateConfig.isPending}
                    onCheckedChange={() => toggleMethod(m)}
                  />
                  {t(m as TKey)}
                </label>
              );
            })}
          </div>
          {methods.length <= 1 && (
            <p className="text-xs text-muted-foreground">
              {t("at_least_one_method")}
            </p>
          )}
        </CardContent>
      </Card>

      {/* ── Manual admins ── */}
      {manualEnabled && (
        <Card>
          <CardHeader>
            <CardTitle>{t("manual_attendance_admins")}</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <p className="text-body-md text-muted-foreground">
              {t("manual_admins_hint")}
            </p>
            {adminList.length === 0 ? (
              <p className="text-body-md text-muted-foreground">{t("none")}</p>
            ) : (
              <div className="space-y-2">
                {adminList.map((a) => (
                  <label
                    key={a.id}
                    className="flex items-center gap-2 text-body-md"
                  >
                    <Checkbox
                      checked={manualIds.includes(a.id)}
                      disabled={updateConfig.isPending}
                      onCheckedChange={() => toggleManualAdmin(a.id)}
                    />
                    {a.name}
                  </label>
                ))}
              </div>
            )}
          </CardContent>
        </Card>
      )}

      {/* ── Face recognition ── */}
      {faceEnabled && <FaceSettingsCard config={config} />}

      {/* ── Allow offline ── */}
      <Card>
        <CardContent className="flex items-start justify-between gap-4 p-4">
          <div>
            <p className="font-medium">{t("allow_offline_attendance")}</p>
            <p className="text-body-md text-muted-foreground">
              {t("allow_offline_hint")}
            </p>
          </div>
          <Checkbox
            checked={config.allow_offline_attendance}
            disabled={updateConfig.isPending}
            onCheckedChange={(v) =>
              saveTenant({ allow_offline_attendance: Boolean(v) })
            }
          />
        </CardContent>
      </Card>

      {/* ── Reject mocked GPS ── */}
      <Card>
        <CardContent className="flex items-start justify-between gap-4 p-4">
          <div>
            <p className="font-medium">{t("reject_mock_location")}</p>
            <p className="text-body-md text-muted-foreground">
              {t("reject_mock_location_hint")}
            </p>
          </div>
          <Checkbox
            checked={config.reject_mock_location}
            disabled={updateConfig.isPending}
            onCheckedChange={(v) =>
              saveTenant({ reject_mock_location: Boolean(v) })
            }
          />
        </CardContent>
      </Card>

      {/* ── Browser attendance channel ── */}
      <WebAttendanceCard config={config} />

      {/* ── Company geofence ── */}
      <GeofenceCard config={config} save={setGeofence} />

      {/* ── Branch overrides ── */}
      <BranchOverrides branches={config.branches} />

      {/* ── Category overrides ── */}
      <CategoryOverrides categories={config.categories} />

      {/* ── Employee overrides ── */}
      <EmployeeOverrides overrides={config.employee_overrides} />
    </div>
  );
}

/**
 * Company-wide face settings. Only rendered once face_selfie is enabled —
 * these knobs are meaningless otherwise and would just add noise.
 */
function FaceSettingsCard({ config }: { config: AttendanceMethodConfig }) {
  const { t } = useT();
  const save = useUpdateFaceSettings();
  const [threshold, setThreshold] = useState(config.face_match_threshold);

  const enforcing = config.face_enforce_mode === "enforce";

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t("face_settings")}</CardTitle>
      </CardHeader>
      <CardContent className="space-y-5">
        <p className="text-body-md text-muted-foreground">
          {t("face_settings_hint")}
        </p>

        {/* Threshold */}
        <div className="space-y-2">
          <div className="flex items-center justify-between gap-2">
            <Label htmlFor="face-threshold">{t("face_match_threshold")}</Label>
            <span className="font-mono text-body-md tabular-nums">
              {threshold.toFixed(2)}
            </span>
          </div>
          <input
            id="face-threshold"
            type="range"
            min={0.3}
            max={0.95}
            step={0.01}
            value={threshold}
            disabled={save.isPending}
            onChange={(e) => setThreshold(Number(e.target.value))}
            onPointerUp={() => save.mutate({ face_match_threshold: threshold })}
            onKeyUp={() => save.mutate({ face_match_threshold: threshold })}
            className="w-full accent-[var(--brand)]"
          />
          <p className="text-xs text-muted-foreground">
            {t("face_match_threshold_hint")}
          </p>
        </div>

        {/* Liveness */}
        <div className="flex items-start justify-between gap-4">
          <div className="min-w-0">
            <p className="font-medium">{t("face_liveness_required")}</p>
            <p className="text-body-md text-muted-foreground">
              {t("face_liveness_hint")}
            </p>
          </div>
          <Checkbox
            checked={config.face_liveness_required}
            disabled={save.isPending}
            onCheckedChange={(v) =>
              save.mutate({ face_liveness_required: Boolean(v) })
            }
          />
        </div>

        {/* Enforcement mode */}
        <div className="space-y-2">
          <Label>{t("face_enforce_mode")}</Label>
          <Select
            value={config.face_enforce_mode}
            onValueChange={(v) =>
              v &&
              save.mutate({ face_enforce_mode: v as "log_only" | "enforce" })
            }
          >
            <SelectTrigger className="w-full">
              <SelectValue>
                {() =>
                  enforcing ? t("face_mode_enforce") : t("face_mode_log_only")
                }
              </SelectValue>
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="log_only">{t("face_mode_log_only")}</SelectItem>
              <SelectItem value="enforce">{t("face_mode_enforce")}</SelectItem>
            </SelectContent>
          </Select>
          <p className="text-xs text-muted-foreground">{t("face_mode_hint")}</p>
        </div>
      </CardContent>
    </Card>
  );
}

function GeofenceCard({
  config,
  save,
}: {
  config: AttendanceMethodConfig;
  save: ReturnType<typeof useSetCompanyGeofence>;
}) {
  const { t } = useT();
  const [lat, setLat] = useState(config.gps_latitude?.toString() ?? "");
  const [lng, setLng] = useState(config.gps_longitude?.toString() ?? "");
  const [radius, setRadius] = useState(
    (config.gps_radius_meters ?? 100).toString(),
  );

  const hasLocation =
    config.gps_latitude != null && config.gps_longitude != null;

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t("company_geofence")}</CardTitle>
      </CardHeader>
      <CardContent className="space-y-3">
        <p className="text-body-md text-muted-foreground">{t("geofence_hint")}</p>
        {!hasLocation && (
          <p className="text-body-md text-muted-foreground">
            {t("no_company_location")}
          </p>
        )}
        <div className="grid gap-3 sm:grid-cols-3">
          <div className="space-y-1.5">
            <Label>{t("latitude")}</Label>
            <Input
              type="number"
              value={lat}
              onChange={(e) => setLat(e.target.value)}
            />
          </div>
          <div className="space-y-1.5">
            <Label>{t("longitude")}</Label>
            <Input
              type="number"
              value={lng}
              onChange={(e) => setLng(e.target.value)}
            />
          </div>
          <div className="space-y-1.5">
            <Label>{t("radius")}</Label>
            <Input
              type="number"
              value={radius}
              onChange={(e) => setRadius(e.target.value)}
            />
          </div>
        </div>
        <div className="flex gap-2">
          <Button
            size="sm"
            disabled={save.isPending || lat === "" || lng === ""}
            onClick={() =>
              save.mutate({
                gps_latitude: Number(lat),
                gps_longitude: Number(lng),
                gps_radius_meters: Number(radius) || 100,
              })
            }
          >
            {t("save_location")}
          </Button>
          {hasLocation && (
            <Button
              size="sm"
              variant="outline"
              disabled={save.isPending}
              onClick={() => {
                setLat("");
                setLng("");
                save.mutate({
                  gps_latitude: null,
                  gps_longitude: null,
                  gps_radius_meters: null,
                });
              }}
            >
              {t("clear_location")}
            </Button>
          )}
        </div>
      </CardContent>
    </Card>
  );
}

/** Inherit toggle + method checkboxes; value is null when inheriting. */
function MethodChecklist({
  value,
  onChange,
}: {
  value: AttendanceMethod[] | null;
  onChange: (v: AttendanceMethod[] | null) => void;
}) {
  const { t } = useT();
  const inherit = value === null;
  const selected = value ?? [];
  return (
    <div className="space-y-3">
      <label className="flex items-center gap-2 text-body-md">
        <Checkbox
          checked={inherit}
          onCheckedChange={(v) => onChange(v ? null : ["qr_gps"])}
        />
        {t("inherit_company")}
      </label>
      {!inherit && (
        <div className="space-y-2 border-s ps-3">
          {METHODS.map((m) => {
            const checked = selected.includes(m);
            const isLast = checked && selected.length <= 1;
            return (
              <label key={m} className="flex items-center gap-2 text-body-md">
                <Checkbox
                  checked={checked}
                  disabled={isLast}
                  onCheckedChange={() =>
                    onChange(
                      checked
                        ? selected.filter((x) => x !== m)
                        : [...selected, m],
                    )
                  }
                />
                {t(m as TKey)}
              </label>
            );
          })}
        </div>
      )}
    </div>
  );
}

function BranchOverrides({
  branches,
}: {
  branches: AttendanceBranchOverride[];
}) {
  const { t } = useT();
  const update = useUpdateBranchAttendanceConfig();
  const [editing, setEditing] = useState<AttendanceBranchOverride | null>(null);
  const [methods, setMethods] = useState<AttendanceMethod[] | null>(null);
  const [radius, setRadius] = useState("100");
  const [offline, setOffline] = useState(false);
  const [faceThreshold, setFaceThreshold] = useState<string>("");
  const [faceLiveness, setFaceLiveness] = useState<boolean | null>(null);
  const [networksFor, setNetworksFor] = useState<AttendanceBranchOverride | null>(
    null,
  );

  const open = (b: AttendanceBranchOverride) => {
    setEditing(b);
    setMethods(b.attendance_methods);
    setRadius((b.gps_radius_meters ?? 100).toString());
    setOffline(false);
    // Empty string / null mean "inherit the company value".
    setFaceThreshold(b.face_match_threshold?.toString() ?? "");
    setFaceLiveness(b.face_liveness_required);
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t("branch_overrides")}</CardTitle>
      </CardHeader>
      <CardContent className="space-y-2">
        {branches.length === 0 ? (
          <p className="text-body-md text-muted-foreground">{t("none")}</p>
        ) : (
          branches.map((b) => (
            <div
              key={b.id}
              className="flex items-center justify-between gap-2 rounded-lg border p-3"
            >
              <div className="min-w-0">
                <p className="font-medium">{b.name}</p>
                <p className="text-body-md text-muted-foreground">
                  {methodLabels(t, b.attendance_methods)}
                </p>
              </div>
              <div className="flex items-center gap-2">
                {b.attendance_methods && (
                  <Badge variant="secondary">{t("custom_methods")}</Badge>
                )}
                {b.wifi_mode && (
                  <Badge
                    variant={
                      b.wifi_mode === "enforcing" ? "default" : "secondary"
                    }
                  >
                    {t(`wifi_mode_${b.wifi_mode}` as never)}
                  </Badge>
                )}
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => setNetworksFor(b)}
                >
                  {t("wifi_networks")}
                </Button>
                <Button variant="outline" size="sm" onClick={() => open(b)}>
                  {t("edit_methods")}
                </Button>
              </div>
            </div>
          ))
        )}
      </CardContent>

      <BranchNetworksDialog
        branch={networksFor}
        open={networksFor != null}
        onOpenChange={(o) => !o && setNetworksFor(null)}
      />

      <Dialog
        open={editing != null}
        onOpenChange={(o) => !o && setEditing(null)}
      >
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{editing?.name}</DialogTitle>
          </DialogHeader>
          <div className="space-y-4">
            <MethodChecklist value={methods} onChange={setMethods} />
            <div className="space-y-1.5">
              <Label>{t("radius")}</Label>
              <Input
                type="number"
                value={radius}
                onChange={(e) => setRadius(e.target.value)}
              />
            </div>
            <label className="flex items-center gap-2 text-body-md">
              <Checkbox
                checked={offline}
                onCheckedChange={(v) => setOffline(Boolean(v))}
              />
              {t("allow_offline_attendance")}
            </label>

            {(methods ?? []).includes("face_selfie") && (
              <div className="space-y-3 rounded-lg border p-3">
                <p className="font-medium">{t("face_branch_override")}</p>
                <div className="space-y-1.5">
                  <Label>{t("face_match_threshold")}</Label>
                  <Input
                    type="number"
                    min={0.3}
                    max={0.95}
                    step={0.01}
                    placeholder={t("face_inherit_company")}
                    value={faceThreshold}
                    onChange={(e) => setFaceThreshold(e.target.value)}
                  />
                </div>
                <label className="flex items-center gap-2 text-body-md">
                  <Checkbox
                    checked={faceLiveness ?? false}
                    onCheckedChange={(v) => setFaceLiveness(v ? true : null)}
                  />
                  {t("face_liveness_required")}
                </label>
              </div>
            )}
          </div>
          <DialogFooter>
            <DialogClose render={<Button variant="outline" />}>
              {t("cancel")}
            </DialogClose>
            <Button
              disabled={update.isPending}
              onClick={() =>
                editing &&
                update.mutate(
                  {
                    branch_id: editing.id,
                    attendance_methods: methods,
                    gps_radius_meters: Number(radius) || 100,
                    allow_offline_attendance: offline,
                    face_match_threshold:
                      faceThreshold === "" ? null : Number(faceThreshold),
                    face_liveness_required: faceLiveness,
                  },
                  { onSuccess: () => setEditing(null) },
                )
              }
            >
              {update.isPending ? t("saving") : t("save")}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </Card>
  );
}

function CategoryOverrides({
  categories,
}: {
  categories: AttendanceCategoryOverride[];
}) {
  const { t } = useT();
  const setOverride = useSetScopeMethodOverride();
  const [editing, setEditing] = useState<AttendanceCategoryOverride | null>(
    null,
  );
  const [methods, setMethods] = useState<AttendanceMethod[] | null>(null);

  const open = (c: AttendanceCategoryOverride) => {
    setEditing(c);
    setMethods(c.attendance_methods);
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t("category_overrides")}</CardTitle>
      </CardHeader>
      <CardContent className="space-y-2">
        {categories.length === 0 ? (
          <p className="text-body-md text-muted-foreground">{t("none")}</p>
        ) : (
          categories.map((c) => (
            <div
              key={c.id}
              className="flex items-center justify-between gap-2 rounded-lg border p-3"
            >
              <div className="min-w-0">
                <p className="font-medium">{c.name}</p>
                <p className="text-body-md text-muted-foreground">
                  {methodLabels(t, c.attendance_methods)}
                </p>
              </div>
              <div className="flex items-center gap-2">
                {c.attendance_methods && (
                  <Badge variant="secondary">{t("custom_methods")}</Badge>
                )}
                <Button variant="outline" size="sm" onClick={() => open(c)}>
                  {t("edit_methods")}
                </Button>
              </div>
            </div>
          ))
        )}
      </CardContent>

      <Dialog
        open={editing != null}
        onOpenChange={(o) => !o && setEditing(null)}
      >
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{editing?.name}</DialogTitle>
          </DialogHeader>
          <MethodChecklist value={methods} onChange={setMethods} />
          <DialogFooter>
            <DialogClose render={<Button variant="outline" />}>
              {t("cancel")}
            </DialogClose>
            <Button
              disabled={setOverride.isPending}
              onClick={() =>
                editing &&
                setOverride.mutate(
                  {
                    scope_type: "category",
                    scope_id: editing.id,
                    attendance_methods: methods,
                  },
                  { onSuccess: () => setEditing(null) },
                )
              }
            >
              {setOverride.isPending ? t("saving") : t("save")}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </Card>
  );
}

function EmployeeOverrides({
  overrides,
}: {
  overrides: AttendanceEmployeeOverride[];
}) {
  const { t } = useT();
  const setOverride = useSetScopeMethodOverride();
  const employees = useEmployees();
  const [addId, setAddId] = useState<string>("");
  const [methods, setMethods] = useState<AttendanceMethod[] | null>(["qr_gps"]);
  const [dialogOpen, setDialogOpen] = useState(false);

  const overriddenIds = new Set(overrides.map((o) => o.id));
  const empList = (Array.isArray(employees.data) ? employees.data : []).filter(
    (e) => !overriddenIds.has(e.id),
  );

  const addName =
    empList.find((e) => String(e.id) === addId)?.name ?? t("select_employee");

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t("employee_overrides")}</CardTitle>
      </CardHeader>
      <CardContent className="space-y-3">
        {overrides.length === 0 ? (
          <p className="text-body-md text-muted-foreground">{t("none")}</p>
        ) : (
          overrides.map((e) => (
            <div
              key={e.id}
              className="flex items-center justify-between gap-2 rounded-lg border p-3"
            >
              <div className="min-w-0">
                <p className="font-medium">{e.name}</p>
                <p className="text-body-md text-muted-foreground">
                  {e.branch_name ? `${e.branch_name} · ` : ""}
                  {methodLabels(t, e.attendance_methods)}
                </p>
              </div>
              <Button
                variant="ghost"
                size="sm"
                disabled={setOverride.isPending}
                onClick={() =>
                  setOverride.mutate({
                    scope_type: "employee",
                    scope_id: e.id,
                    attendance_methods: null,
                  })
                }
              >
                {t("clear_override")}
              </Button>
            </div>
          ))
        )}

        {/* Add new override */}
        <div className="flex items-center gap-2 pt-1">
          <Select value={addId} onValueChange={(v) => setAddId(v ?? "")}>
            <SelectTrigger className="w-full">
              <SelectValue placeholder={t("select_employee")}>
                {() => addName}
              </SelectValue>
            </SelectTrigger>
            <SelectContent className="max-h-72">
              {empList.map((e) => (
                <SelectItem key={e.id} value={String(e.id)}>
                  {e.name}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          <Button
            size="sm"
            disabled={!addId}
            onClick={() => {
              setMethods(["qr_gps"]);
              setDialogOpen(true);
            }}
          >
            {t("add")}
          </Button>
        </div>
      </CardContent>

      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{t("add_employee_override")}</DialogTitle>
          </DialogHeader>
          <MethodChecklist value={methods} onChange={setMethods} />
          <DialogFooter>
            <DialogClose render={<Button variant="outline" />}>
              {t("cancel")}
            </DialogClose>
            <Button
              disabled={setOverride.isPending || !addId}
              onClick={() =>
                setOverride.mutate(
                  {
                    scope_type: "employee",
                    scope_id: Number(addId),
                    attendance_methods: methods,
                  },
                  {
                    onSuccess: () => {
                      setDialogOpen(false);
                      setAddId("");
                    },
                  },
                )
              }
            >
              {setOverride.isPending ? t("saving") : t("save")}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </Card>
  );
}
