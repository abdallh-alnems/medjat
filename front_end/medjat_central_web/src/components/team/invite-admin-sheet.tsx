"use client";

import { useState } from "react";
import { toast } from "sonner";
import {
  Award,
  Briefcase,
  CheckCircle2,
  Clock,
  Copy,
  Eye,
  Mail,
  Store,
  type LucideIcon,
} from "lucide-react";
import { useT } from "@/lib/i18n/use-t";
import { cn } from "@/lib/utils";
import { useInviteAdmin } from "@/lib/hooks/use-managers";
import type { InviteAdminResult } from "@/lib/api/managers";
import { useBranches } from "@/lib/hooks/use-org";
import { useAuthStore, type AdminRole } from "@/lib/stores/auth-store";
import {
  PERMISSION_CODES,
  ROLE_DEFAULTS,
  type PermissionCode,
} from "@/lib/permissions/model";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Checkbox } from "@/components/ui/checkbox";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import type { TKey } from "@/lib/i18n/ar";

const ROLES: { value: AdminRole; label: TKey; Icon: LucideIcon; gmOnly?: boolean }[] =
  [
    { value: "general_manager", label: "general_manager", Icon: Award, gmOnly: true },
    { value: "hr", label: "hr", Icon: Briefcase },
    { value: "branch_manager", label: "branch_manager", Icon: Store },
    { value: "attendance", label: "attendance_role", Icon: Clock },
    { value: "viewer", label: "viewer", Icon: Eye },
  ];

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

/** Role default permissions as a boolean map (matches the app's defaults). */
function defaultsFor(role: AdminRole): Record<PermissionCode, boolean> {
  const defaults = ROLE_DEFAULTS[role];
  const map = {} as Record<PermissionCode, boolean>;
  for (const code of PERMISSION_CODES) {
    map[code] = defaults === "*" ? true : defaults.includes(code);
  }
  return map;
}

interface Props {
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

/**
 * Invite a new admin — mirrors the mobile app's flow: email, role (chips),
 * optional custom permissions, branch scope, then the shareable invitation code.
 */
export function InviteAdminSheet({ open, onOpenChange }: Props) {
  const { t } = useT();
  const invite = useInviteAdmin();
  const branchesQuery = useBranches();
  const isGM = useAuthStore((s) => s.user?.role === "general_manager");

  const [email, setEmail] = useState("");
  const [emailError, setEmailError] = useState<string | null>(null);
  const [role, setRole] = useState<AdminRole>("hr");
  const [customize, setCustomize] = useState(false);
  const [perms, setPerms] = useState<Record<PermissionCode, boolean>>(() =>
    defaultsFor("hr"),
  );
  const [branchId, setBranchId] = useState<number | null>(null);
  const [code, setCode] = useState<string | null>(null);

  const branches = Array.isArray(branchesQuery.data) ? branchesQuery.data : [];
  const roleOptions = ROLES.filter((r) => !r.gmOnly || isGM);

  const reset = () => {
    setEmail("");
    setEmailError(null);
    setRole("hr");
    setCustomize(false);
    setPerms(defaultsFor("hr"));
    setBranchId(null);
    setCode(null);
  };

  const handleOpenChange = (next: boolean) => {
    if (!next) reset();
    onOpenChange(next);
  };

  const onRoleChange = (next: AdminRole) => {
    setRole(next);
    setCustomize(false);
    setPerms(defaultsFor(next));
  };

  const submit = () => {
    const trimmed = email.trim();
    if (!trimmed) {
      setEmailError(t("required"));
      return;
    }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(trimmed)) {
      setEmailError(t("invalid_email"));
      return;
    }
    setEmailError(null);

    const permissions =
      customize && role !== "general_manager"
        ? PERMISSION_CODES.filter((c) => perms[c])
        : undefined;

    invite.mutate(
      { email: trimmed, role, branch_id: branchId, permissions },
      {
        // The API client resolves error responses too (it doesn't throw), so a
        // backend rejection arrives here as a body WITHOUT a code. Distinguish a
        // real success from an error envelope and surface its message instead of
        // silently doing nothing.
        onSuccess: (data) => {
          const body = data as Partial<InviteAdminResult> & {
            message?: string;
          };
          if (body.invitation_code) {
            setCode(body.invitation_code);
          } else {
            toast.error(body.message || t("error_generic"));
          }
        },
      },
    );
  };

  return (
    <Sheet open={open} onOpenChange={handleOpenChange}>
      <SheetContent
        side="left"
        className="flex w-full max-w-md flex-col gap-0 overflow-y-auto"
      >
        <SheetHeader>
          <SheetTitle>{t("invite_admin")}</SheetTitle>
        </SheetHeader>

        {code ? (
          <div className="flex flex-1 flex-col items-center gap-4 px-4 py-8 text-center">
            <div className="flex h-16 w-16 items-center justify-center rounded-2xl bg-success/10">
              <CheckCircle2 className="h-8 w-8 text-success" />
            </div>
            <p className="text-body-lg font-medium">{t("share_invitation_with")}</p>
            <p className="text-body-sm text-muted-foreground">
              {t("invitation_code_label")}
            </p>
            <div className="rounded-lg border-2 border-primary bg-primary/10 px-6 py-4">
              <span className="font-mono text-3xl font-bold tracking-[0.3em] text-primary">
                {code}
              </span>
            </div>
            <p className="text-body-sm text-muted-foreground">
              {t("invitation_valid_for")}
            </p>
            <div className="flex w-full items-center gap-2 rounded-lg bg-muted/50 px-3 py-2 text-start">
              <Mail className="h-4 w-4 shrink-0 text-muted-foreground" />
              <span className="text-body-sm">
                {t("invitation_email_sent")}{" "}
                <span className="font-medium break-all">{email}</span>
              </span>
            </div>
            <Button
              variant="outline"
              onClick={() => {
                void navigator.clipboard?.writeText(code);
                toast.success(t("code_copied"));
              }}
            >
              <Copy className="h-4 w-4" />
              {t("copy_code")}
            </Button>
            <div className="flex-1" />
            <Button className="w-full" onClick={() => handleOpenChange(false)}>
              {t("done")}
            </Button>
          </div>
        ) : (
          <div className="flex flex-col gap-5 px-4 py-4">
            {/* Email */}
            <div className="space-y-1.5">
              <Label>{t("admin_email")}</Label>
              <Input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                aria-invalid={emailError != null}
              />
              {emailError && (
                <p className="text-body-sm text-destructive">{emailError}</p>
              )}
            </div>

            {/* Role chips */}
            <div className="space-y-2">
              <Label>{t("admin_role")}</Label>
              <div className="flex flex-wrap gap-2">
                {roleOptions.map(({ value, label, Icon }) => {
                  const selected = role === value;
                  return (
                    <button
                      key={value}
                      type="button"
                      onClick={() => onRoleChange(value)}
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

            {/* Custom permissions (hidden for general manager — full access) */}
            {role !== "general_manager" && (
              <div className="space-y-2">
                <label className="flex items-start gap-2">
                  <Checkbox
                    checked={customize}
                    onCheckedChange={(v) => {
                      const on = Boolean(v);
                      setCustomize(on);
                      if (!on) setPerms(defaultsFor(role));
                    }}
                    className="mt-0.5"
                  />
                  <span>
                    <span className="block text-body-md font-medium">
                      {t("customize_permissions")}
                    </span>
                    <span className="block text-body-sm text-muted-foreground">
                      {t("customize_permissions_hint")}
                    </span>
                  </span>
                </label>

                {customize && (
                  <div className="space-y-1 rounded-lg border p-2">
                    {PERMISSION_CODES.map((c) => (
                      <label
                        key={c}
                        className="flex items-center justify-between rounded-md px-2 py-1.5 hover:bg-muted/50"
                      >
                        <span className="text-body-md">{t(PERM_LABEL[c])}</span>
                        <Checkbox
                          checked={perms[c]}
                          onCheckedChange={(v) =>
                            setPerms((p) => ({ ...p, [c]: Boolean(v) }))
                          }
                        />
                      </label>
                    ))}
                  </div>
                )}
              </div>
            )}

            {/* Branch scope */}
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

            <Button
              className="mt-2 w-full"
              onClick={submit}
              disabled={invite.isPending}
            >
              {t("send_invitation")}
            </Button>
          </div>
        )}
      </SheetContent>
    </Sheet>
  );
}
