"use client";

import { useState } from "react";
import { toast } from "sonner";
import { useT } from "@/lib/i18n/use-t";
import {
  useAdmins,
  useInvitations,
  useCancelInvitation,
  useResendInvitation,
  useSetAdminActive,
  useRemoveAdmin,
} from "@/lib/hooks/use-managers";
import { LoadingState, ErrorState, EmptyState } from "@/components/ui/states";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { PermissionsEditor } from "@/components/team/permissions-editor";
import { InviteAdminSheet } from "@/components/team/invite-admin-sheet";
import { EditAdminSheet } from "@/components/team/edit-admin-sheet";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Copy, Plus, Search } from "lucide-react";
import { cn } from "@/lib/utils";
import { useAuthStore, type AdminRole } from "@/lib/stores/auth-store";
import type { Admin, ManagerInvitation } from "@/lib/types";
import type { TKey } from "@/lib/i18n/ar";

const ROLE_KEY: Record<AdminRole, TKey> = {
  general_manager: "general_manager",
  hr: "hr",
  branch_manager: "branch_manager",
  attendance: "attendance_role",
  viewer: "viewer",
};

type InviteStatus = "pending" | "accepted" | "cancelled" | "expired";

function inviteStatus(inv: ManagerInvitation): InviteStatus {
  if (inv.cancelled_at) return "cancelled";
  if (inv.accepted_at) return "accepted";
  if (inv.expires_at && new Date(inv.expires_at).getTime() < Date.now())
    return "expired";
  return "pending";
}

const STATUS_KEY: Record<InviteStatus, TKey> = {
  pending: "status_pending",
  accepted: "status_accepted",
  cancelled: "status_cancelled",
  expired: "status_expired",
};

const STATUS_VARIANT: Record<
  InviteStatus,
  "default" | "secondary" | "destructive"
> = {
  pending: "default",
  accepted: "secondary",
  cancelled: "destructive",
  expired: "secondary",
};

const FILTERS: { value: InviteStatus | "all"; label: TKey }[] = [
  { value: "pending", label: "filter_pending" },
  { value: "accepted", label: "filter_accepted" },
  { value: "expired", label: "filter_expired" },
  { value: "cancelled", label: "filter_cancelled" },
  { value: "all", label: "filter_all" },
];

const shortDate = (raw?: string | null) => (raw ? raw.slice(0, 16) : "");

export default function TeamPage() {
  const { t } = useT();
  const admins = useAdmins();
  const invitations = useInvitations();
  const cancel = useCancelInvitation();
  const resend = useResendInvitation();
  const setActive = useSetAdminActive();
  const remove = useRemoveAdmin();
  const currentUserId = useAuthStore((s) => s.user?.id ?? null);

  const [editing, setEditing] = useState<number | null>(null);
  const [editRoleAdmin, setEditRoleAdmin] = useState<Admin | null>(null);
  const [inviteOpen, setInviteOpen] = useState(false);
  const [removeTarget, setRemoveTarget] = useState<Admin | null>(null);
  const [adminSearch, setAdminSearch] = useState("");
  const [inviteFilter, setInviteFilter] = useState<InviteStatus | "all">(
    "pending",
  );
  const [resendCode, setResendCode] = useState<string | null>(null);

  const adminList = Array.isArray(admins.data) ? admins.data : [];
  const inviteList = Array.isArray(invitations.data) ? invitations.data : [];

  const q = adminSearch.trim().toLowerCase();
  const filteredAdmins = q
    ? adminList.filter(
        (a) =>
          a.name.toLowerCase().includes(q) ||
          a.email.toLowerCase().includes(q) ||
          (a.branch_name ?? "").toLowerCase().includes(q),
      )
    : adminList;

  const filteredInvites =
    inviteFilter === "all"
      ? inviteList
      : inviteList.filter((inv) => inviteStatus(inv) === inviteFilter);

  // The tab badge counts only actionable (pending) invitations.
  const pendingCount = inviteList.filter(
    (inv) => inviteStatus(inv) === "pending",
  ).length;

  const doResend = (id: number) => {
    resend.mutate(id, {
      onSuccess: (data) => {
        const code = (data as { invitation_code?: string })?.invitation_code;
        if (code) setResendCode(code);
      },
    });
  };

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between gap-2">
        <h1 className="text-headline-md font-bold">{t("team")}</h1>
        <Button size="sm" onClick={() => setInviteOpen(true)}>
          <Plus className="h-4 w-4" />
          {t("invite_admin")}
        </Button>
      </div>

      <InviteAdminSheet open={inviteOpen} onOpenChange={setInviteOpen} />

      <Tabs defaultValue="admins">
        <TabsList className="grid w-full max-w-sm grid-cols-2">
          <TabsTrigger value="admins">{t("admins_tab")}</TabsTrigger>
          <TabsTrigger value="invitations">
            {t("invitations_tab")}
            {pendingCount > 0 && (
              <Badge variant="secondary" className="ms-1.5">
                {pendingCount}
              </Badge>
            )}
          </TabsTrigger>
        </TabsList>

        {/* ── Admins ── */}
        <TabsContent value="admins" className="space-y-3">
          <div className="relative">
            <Search className="pointer-events-none absolute inset-y-0 start-3 my-auto h-4 w-4 text-muted-foreground" />
            <Input
              value={adminSearch}
              onChange={(e) => setAdminSearch(e.target.value)}
              placeholder={t("search_admins")}
              className="ps-9"
            />
          </div>

          {admins.isLoading ? (
            <LoadingState />
          ) : admins.isError ? (
            <ErrorState onRetry={() => admins.refetch()} />
          ) : filteredAdmins.length === 0 ? (
            <EmptyState message={q ? t("no_results") : t("no_admins_yet")} />
          ) : (
            <div className="rounded-lg border">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>{t("name")}</TableHead>
                    <TableHead>{t("email")}</TableHead>
                    <TableHead>{t("role")}</TableHead>
                    <TableHead>{t("branch")}</TableHead>
                    <TableHead>{t("last_login")}</TableHead>
                    <TableHead>{t("status")}</TableHead>
                    <TableHead>{t("actions")}</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {filteredAdmins.map((a) => (
                    <TableRow key={a.id}>
                      <TableCell className="font-medium">{a.name}</TableCell>
                      <TableCell>{a.email}</TableCell>
                      <TableCell>{t(ROLE_KEY[a.role])}</TableCell>
                      <TableCell className="text-muted-foreground">
                        {a.branch_name ?? t("all_branches")}
                      </TableCell>
                      <TableCell className="text-muted-foreground">
                        {a.last_login_at
                          ? shortDate(a.last_login_at)
                          : t("never_logged_in")}
                      </TableCell>
                      <TableCell>
                        <Badge variant={a.is_active ? "default" : "secondary"}>
                          {a.is_active ? t("active") : t("suspended")}
                        </Badge>
                      </TableCell>
                      <TableCell>
                        {a.id === currentUserId ? (
                          <Badge variant="secondary">{t("you_label")}</Badge>
                        ) : a.can_manage === false ? (
                          <span className="text-muted-foreground">—</span>
                        ) : (
                          <div className="flex gap-1">
                            <Button
                              variant="ghost"
                              size="sm"
                              onClick={() => setEditRoleAdmin(a)}
                            >
                              {t("edit_role_branch")}
                            </Button>
                            {a.role !== "general_manager" && (
                              <Button
                                variant="ghost"
                                size="sm"
                                onClick={() => setEditing(a.id)}
                              >
                                {t("edit_permissions")}
                              </Button>
                            )}
                            <Button
                              variant="ghost"
                              size="sm"
                              onClick={() =>
                                setActive.mutate({
                                  id: a.id,
                                  active: !a.is_active,
                                })
                              }
                            >
                              {a.is_active ? t("deactivate") : t("activate")}
                            </Button>
                            <Button
                              variant="ghost"
                              size="sm"
                              onClick={() => setRemoveTarget(a)}
                            >
                              {t("remove_admin")}
                            </Button>
                          </div>
                        )}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          )}
        </TabsContent>

        {/* ── Invitations ── */}
        <TabsContent value="invitations" className="space-y-3">
          <div className="flex flex-wrap gap-2">
            {FILTERS.map((f) => {
              const selected = inviteFilter === f.value;
              return (
                <button
                  key={f.value}
                  type="button"
                  onClick={() => setInviteFilter(f.value)}
                  className={cn(
                    "rounded-full border px-3 py-1 text-body-sm transition-colors",
                    selected
                      ? "border-primary bg-primary/10 text-primary"
                      : "border-border text-foreground hover:bg-muted/50",
                  )}
                >
                  {t(f.label)}
                </button>
              );
            })}
          </div>

          {invitations.isLoading ? (
            <LoadingState />
          ) : invitations.isError ? (
            <ErrorState onRetry={() => invitations.refetch()} />
          ) : filteredInvites.length === 0 ? (
            <EmptyState message={t("no_pending_invitations")} />
          ) : (
            <div className="rounded-lg border">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>{t("email")}</TableHead>
                    <TableHead>{t("role")}</TableHead>
                    <TableHead>{t("branch")}</TableHead>
                    <TableHead>{t("status")}</TableHead>
                    <TableHead>{t("invitation_expires_at")}</TableHead>
                    <TableHead>{t("actions")}</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {filteredInvites.map((inv) => {
                    const status = inviteStatus(inv);
                    return (
                      <TableRow key={inv.id}>
                        <TableCell className="font-medium">
                          {inv.name && inv.name.trim() ? inv.name : inv.email}
                        </TableCell>
                        <TableCell>{t(ROLE_KEY[inv.role])}</TableCell>
                        <TableCell className="text-muted-foreground">
                          {inv.branch_name ?? t("all_branches")}
                        </TableCell>
                        <TableCell>
                          <Badge variant={STATUS_VARIANT[status]}>
                            {t(STATUS_KEY[status])}
                          </Badge>
                        </TableCell>
                        <TableCell className="text-muted-foreground">
                          {shortDate(inv.expires_at)}
                        </TableCell>
                        <TableCell>
                          <div className="flex gap-1">
                            {(status === "expired" ||
                              status === "cancelled") && (
                              <Button
                                variant="ghost"
                                size="sm"
                                onClick={() => doResend(inv.id)}
                              >
                                {t("resend_code")}
                              </Button>
                            )}
                            {status === "pending" && (
                              <Button
                                variant="ghost"
                                size="sm"
                                onClick={() => cancel.mutate(inv.id)}
                              >
                                {t("cancel_invitation")}
                              </Button>
                            )}
                          </div>
                        </TableCell>
                      </TableRow>
                    );
                  })}
                </TableBody>
              </Table>
            </div>
          )}
        </TabsContent>
      </Tabs>

      <PermissionsEditor adminId={editing} onClose={() => setEditing(null)} />
      <EditAdminSheet admin={editRoleAdmin} onClose={() => setEditRoleAdmin(null)} />

      {/* Confirm before removing a team member */}
      <Dialog
        open={removeTarget != null}
        onOpenChange={(o) => !o && setRemoveTarget(null)}
      >
        <DialogContent className="sm:max-w-sm">
          <DialogHeader>
            <DialogTitle>{t("remove_admin")}</DialogTitle>
          </DialogHeader>
          <p className="text-body-md">
            <span className="font-medium">{removeTarget?.name}</span>
            {" — "}
            {t("remove_admin_confirm")}
          </p>
          <DialogFooter>
            <DialogClose render={<Button variant="outline" />}>
              {t("cancel")}
            </DialogClose>
            <Button
              variant="destructive"
              onClick={() => {
                if (removeTarget) remove.mutate(removeTarget.id);
                setRemoveTarget(null);
              }}
            >
              {t("remove_admin")}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* New code after a resend */}
      <Dialog
        open={resendCode != null}
        onOpenChange={(o) => !o && setResendCode(null)}
      >
        <DialogContent className="sm:max-w-sm">
          <DialogHeader>
            <DialogTitle>{t("invitation_code_label")}</DialogTitle>
          </DialogHeader>
          <div className="flex flex-col items-center gap-3 py-2">
            <div className="rounded-lg border-2 border-primary bg-primary/10 px-6 py-4">
              <span className="font-mono text-3xl font-bold tracking-[0.3em] text-primary">
                {resendCode}
              </span>
            </div>
            <p className="text-body-sm text-muted-foreground">
              {t("invitation_valid_for")}
            </p>
            <Button
              variant="outline"
              onClick={() => {
                if (resendCode) void navigator.clipboard?.writeText(resendCode);
                toast.success(t("code_copied"));
              }}
            >
              <Copy className="h-4 w-4" />
              {t("copy_code")}
            </Button>
          </div>
          <DialogFooter>
            <DialogClose render={<Button variant="outline" />}>
              {t("done")}
            </DialogClose>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
