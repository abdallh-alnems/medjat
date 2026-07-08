"use client";

import { useState } from "react";
import { Award, Briefcase, Clock, Eye, Store, type LucideIcon } from "lucide-react";
import { useT } from "@/lib/i18n/use-t";
import { cn } from "@/lib/utils";
import { useUpdateAdmin } from "@/lib/hooks/use-managers";
import { useBranches } from "@/lib/hooks/use-org";
import { useAuthStore, type AdminRole } from "@/lib/stores/auth-store";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Sheet,
  SheetClose,
  SheetContent,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import type { Admin } from "@/lib/types";
import type { TKey } from "@/lib/i18n/ar";

const ROLES: { value: AdminRole; label: TKey; Icon: LucideIcon; gmOnly?: boolean }[] =
  [
    { value: "general_manager", label: "general_manager", Icon: Award, gmOnly: true },
    { value: "hr", label: "hr", Icon: Briefcase },
    { value: "branch_manager", label: "branch_manager", Icon: Store },
    { value: "attendance", label: "attendance_role", Icon: Clock },
    { value: "viewer", label: "viewer", Icon: Eye },
  ];

interface Props {
  admin: Admin | null;
  onClose: () => void;
}

/** Edit an existing admin's role and branch scope — mirrors the mobile app. */
export function EditAdminSheet({ admin, onClose }: Props) {
  const { t } = useT();
  return (
    <Sheet open={admin != null} onOpenChange={(o) => !o && onClose()}>
      <SheetContent
        side="left"
        className="flex w-full max-w-md flex-col gap-0 overflow-y-auto"
      >
        <SheetHeader>
          <SheetTitle>{t("edit_role_branch")}</SheetTitle>
        </SheetHeader>
        {/* Remount per admin so the form initialises from that admin's values. */}
        {admin && <EditAdminForm key={admin.id} admin={admin} onClose={onClose} />}
      </SheetContent>
    </Sheet>
  );
}

function EditAdminForm({
  admin,
  onClose,
}: {
  admin: Admin;
  onClose: () => void;
}) {
  const { t } = useT();
  const update = useUpdateAdmin();
  const branchesQuery = useBranches();
  const isGM = useAuthStore((s) => s.user?.role === "general_manager");

  const [role, setRole] = useState<AdminRole>(admin.role);
  const [branchId, setBranchId] = useState<number | null>(admin.branch_id ?? null);

  const branches = Array.isArray(branchesQuery.data) ? branchesQuery.data : [];
  // Only a general manager (or an already-GM target) may keep/grant the top role.
  const roleOptions = ROLES.filter(
    (r) => !r.gmOnly || isGM || admin.role === "general_manager",
  );

  const save = () => {
    update.mutate(
      { id: admin.id, role, branch_id: branchId },
      { onSuccess: () => onClose() },
    );
  };

  return (
    <>
      <div className="flex flex-col gap-5 px-4 py-4">
        <div className="space-y-2">
          <Label>{t("admin_role")}</Label>
          <div className="flex flex-wrap gap-2">
            {roleOptions.map(({ value, label, Icon }) => {
              const selected = role === value;
              return (
                <button
                  key={value}
                  type="button"
                  onClick={() => setRole(value)}
                  className={cn(
                    "flex items-center gap-1.5 rounded-full border px-3 py-1.5 text-body-sm transition-colors",
                    selected
                      ? "border-primary bg-primary/10 text-primary"
                      : "border-border text-foreground hover:bg-muted/50",
                  )}
                >
                  <Icon className="h-3.5 w-3.5" />
                  {t(label)}
                </button>
              );
            })}
          </div>
        </div>

        <div className="space-y-1.5">
          <Label>{t("branch")}</Label>
          <Select
            value={branchId == null ? "all" : String(branchId)}
            onValueChange={(v) =>
              setBranchId(v == null || v === "all" ? null : Number(v))
            }
          >
            <SelectTrigger>
              <SelectValue>
                {(v) =>
                  v == null || v === "all"
                    ? t("all_branches")
                    : (branches.find((b) => String(b.id) === v)?.name ?? "")
                }
              </SelectValue>
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">{t("all_branches")}</SelectItem>
              {branches.map((b) => (
                <SelectItem key={b.id} value={String(b.id)}>
                  {b.name}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
      </div>

      <SheetFooter>
        <SheetClose render={<Button variant="outline" />}>{t("cancel")}</SheetClose>
        <Button onClick={save} disabled={update.isPending}>
          {t("save")}
        </Button>
      </SheetFooter>
    </>
  );
}
