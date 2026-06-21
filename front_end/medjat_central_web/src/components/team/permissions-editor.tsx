"use client";

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
import { useT } from "@/lib/i18n/use-t";
import {
  useAdminPermissions,
  useUpdateAdminPermissions,
  useResetAdminPermissions,
} from "@/lib/hooks/use-managers";
import { useAdmins } from "@/lib/hooks/use-managers";
import {
  PERMISSION_CODES,
  resolvePermissions,
} from "@/lib/permissions/model";
import type { PermissionCode } from "@/lib/permissions/model";
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
  const { data: admins } = useAdmins();
  const admin = (admins ?? []).find((a) => a.id === adminId) ?? null;
  const perms = useAdminPermissions(adminId);
  const update = useUpdateAdminPermissions();
  const reset = useResetAdminPermissions();

  const isGM = admin?.role === "general_manager";
  const effective = isGM
    ? null
    : perms.data ?? resolvePermissions(admin?.role ?? null, null);

  if (adminId && !admin) {
    return (
      <Dialog open={adminId != null} onOpenChange={(o) => !o && onClose()}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>{t("error_generic")}</DialogTitle>
          </DialogHeader>
          <p className="text-body-md text-muted-foreground">{t("no_data")}</p>
          <DialogFooter>
            <DialogClose render={<Button variant="outline" />}>
              {t("close")}
            </DialogClose>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    );
  }

  const toggle = (code: PermissionCode, value: boolean) => {
    if (perms.isLoading || !perms.data) return;
    const next = { ...perms.data };
    next[code] = value;
    update.mutate({ adminId: adminId as number, permissions: next });
  };

  return (
    <Dialog open={adminId != null} onOpenChange={(o) => !o && onClose()}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>
            {t("edit_permissions")}
            {isGM && (
              <Badge variant="secondary" className="ms-2">
                {t("gm_locked")}
              </Badge>
            )}
          </DialogTitle>
        </DialogHeader>

        {isGM ? (
          <p className="text-body-md text-muted-foreground">
            {t("gm_locked")}
          </p>
        ) : (
          <div className="max-h-80 space-y-1 overflow-y-auto">
            {PERMISSION_CODES.map((code) => (
              <label
                key={code}
                className="flex items-center justify-between rounded-lg px-2 py-1.5 hover:bg-muted/50"
              >
                <span className="text-body-md">{t(PERM_LABEL[code])}</span>
                <Checkbox
                  checked={effective?.[code] ?? false}
                  onCheckedChange={(v) => toggle(code, Boolean(v))}
                  disabled={perms.isLoading || update.isPending}
                />
              </label>
            ))}
          </div>
        )}

        <DialogFooter>
          {!isGM && (
            <Button
              variant="outline"
              onClick={() => reset.mutate(adminId as number)}
              disabled={reset.isPending}
            >
              {t("reset_permissions")}
            </Button>
          )}
          <DialogClose render={<Button variant="outline" />}>
            {t("close")}
          </DialogClose>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
