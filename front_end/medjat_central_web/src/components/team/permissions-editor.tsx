"use client";

import { useState } from "react";
import { Info } from "lucide-react";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
  DialogClose,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { Badge } from "@/components/ui/badge";
import { LoadingState } from "@/components/ui/states";
import { useT } from "@/lib/i18n/use-t";
import {
  useAdminPermissions,
  useUpdateAdminPermissions,
  useResetAdminPermissions,
} from "@/lib/hooks/use-managers";
import type { AdminPermissions } from "@/lib/api/managers";
import { PERMISSION_CODES, type PermissionCode } from "@/lib/permissions/model";
import type { TKey } from "@/lib/i18n/ar";

const PERM_LABEL: Record<PermissionCode, TKey> = {
  manage_employees: "perm_manage_employees",
  manage_deduction_rules: "perm_manage_deduction_rules",
  manage_attendance: "perm_manage_attendance",
  view_reports: "perm_view_reports",
  manage_documents: "perm_manage_documents",
  documents_manage_types: "perm_documents_manage_types",
  documents_verify: "perm_documents_verify",
  documents_view_reports: "perm_documents_view_reports",
  manage_payroll: "perm_manage_payroll",
  manage_leaves: "perm_manage_leaves",
  manage_assets: "perm_manage_assets",
  add_managers: "perm_add_managers",
  manage_company_settings: "perm_manage_company_settings",
  manage_support: "perm_manage_support",
};

interface Props {
  adminId: number | null;
  onClose: () => void;
}

/** Per-admin permission overrides editor. General Manager is locked (all granted). */
export function PermissionsEditor({ adminId, onClose }: Props) {
  const { t } = useT();
  const perms = useAdminPermissions(adminId);

  return (
    <Dialog open={adminId != null} onOpenChange={(o) => !o && onClose()}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            {t("permissions_for_admin")}
            {perms.data?.is_customized && (
              <Badge variant="secondary">{t("customized_permissions")}</Badge>
            )}
          </DialogTitle>
        </DialogHeader>

        {adminId == null ? null : perms.isLoading ? (
          <LoadingState />
        ) : perms.data ? (
          <PermForm
            key={adminId}
            adminId={adminId}
            data={perms.data}
            onClose={onClose}
          />
        ) : (
          <p className="text-body-md text-muted-foreground">{t("no_data")}</p>
        )}
      </DialogContent>
    </Dialog>
  );
}

function PermForm({
  adminId,
  data,
  onClose,
}: {
  adminId: number;
  data: AdminPermissions;
  onClose: () => void;
}) {
  const { t } = useT();
  const update = useUpdateAdminPermissions();
  const reset = useResetAdminPermissions();

  const isGM = data.role === "general_manager";
  const roleDefaults = new Set(data.role_defaults);
  const codes = (
    data.all_permissions.length ? data.all_permissions : PERMISSION_CODES
  ) as PermissionCode[];

  const [selected, setSelected] = useState<Set<string>>(
    () => new Set(data.effective_permissions),
  );
  const [confirmingReset, setConfirmingReset] = useState(false);

  if (isGM) {
    return (
      <>
        <p className="text-body-md text-muted-foreground">{t("gm_locked")}</p>
        <DialogFooter>
          <DialogClose render={<Button variant="outline" />}>
            {t("close")}
          </DialogClose>
        </DialogFooter>
      </>
    );
  }

  const toggle = (code: string, value: boolean) => {
    setSelected((prev) => {
      const next = new Set(prev);
      if (value) next.add(code);
      else next.delete(code);
      return next;
    });
  };

  const save = () => {
    update.mutate(
      { adminId, permissions: [...selected] },
      { onSuccess: () => onClose() },
    );
  };

  const doReset = () => {
    reset.mutate(adminId, { onSuccess: () => onClose() });
  };

  return (
    <>
      <div className="flex items-start gap-2 rounded-lg bg-muted/50 p-3">
        <Info className="mt-0.5 h-4 w-4 shrink-0 text-muted-foreground" />
        <span className="text-body-sm text-muted-foreground">
          {t("permissions_override_hint")}
        </span>
      </div>

      <div className="max-h-80 space-y-1 overflow-y-auto">
        {codes.map((code) => (
          <label
            key={code}
            className="flex items-center justify-between rounded-lg px-2 py-1.5 hover:bg-muted/50"
          >
            <span className="flex items-center gap-2 text-body-md">
              {t(PERM_LABEL[code] ?? (`perm_${code}` as TKey))}
              {roleDefaults.has(code) && (
                <Badge variant="secondary" className="text-label-sm">
                  {t("default_for_role")}
                </Badge>
              )}
            </span>
            <Checkbox
              checked={selected.has(code)}
              onCheckedChange={(v) => toggle(code, Boolean(v))}
            />
          </label>
        ))}
      </div>

      {confirmingReset ? (
        <div className="space-y-2 rounded-lg border p-3">
          <p className="text-body-sm text-muted-foreground">
            {t("reset_permissions_confirm")}
          </p>
          <div className="flex justify-end gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={() => setConfirmingReset(false)}
            >
              {t("cancel")}
            </Button>
            <Button
              variant="destructive"
              size="sm"
              onClick={doReset}
              disabled={reset.isPending}
            >
              {t("reset_to_default")}
            </Button>
          </div>
        </div>
      ) : (
        <DialogFooter className="sm:justify-between">
          {data.is_customized ? (
            <Button variant="outline" onClick={() => setConfirmingReset(true)}>
              {t("reset_to_default")}
            </Button>
          ) : (
            <span />
          )}
          <Button onClick={save} disabled={update.isPending}>
            {t("save")}
          </Button>
        </DialogFooter>
      )}
    </>
  );
}
