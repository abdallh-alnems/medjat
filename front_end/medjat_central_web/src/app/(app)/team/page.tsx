"use client";

import { useState } from "react";
import { useT } from "@/lib/i18n/use-t";
import {
  useAdmins,
  useInvitations,
  useInviteAdmin,
  useCancelInvitation,
  useResendInvitation,
  useSetAdminActive,
  useRemoveAdmin,
} from "@/lib/hooks/use-managers";
import { LoadingState, ErrorState, EmptyState } from "@/components/ui/states";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { PermissionsEditor } from "@/components/team/permissions-editor";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetTrigger,
  SheetFooter,
  SheetClose,
} from "@/components/ui/sheet";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Plus } from "lucide-react";
import type { AdminRole } from "@/lib/stores/auth-store";
import type { TKey } from "@/lib/i18n/ar";

const ROLES: AdminRole[] = [
  "general_manager",
  "hr",
  "branch_manager",
  "attendance",
  "viewer",
];
const ROLE_KEY: Record<AdminRole, TKey> = {
  general_manager: "general_manager",
  hr: "hr",
  branch_manager: "branch_manager",
  attendance: "attendance_role",
  viewer: "viewer",
};

export default function TeamPage() {
  const { t } = useT();
  const admins = useAdmins();
  const invitations = useInvitations();
  const invite = useInviteAdmin();
  const cancel = useCancelInvitation();
  const resend = useResendInvitation();
  const setActive = useSetAdminActive();
  const remove = useRemoveAdmin();

  const [editing, setEditing] = useState<number | null>(null);
  const [open, setOpen] = useState(false);
  const [email, setEmail] = useState("");
  const [role, setRole] = useState<AdminRole>("hr");

  const submit = () => {
    invite.mutate({ email, role }, { onSuccess: () => setOpen(false) });
  };

  const adminList = Array.isArray(admins.data) ? admins.data : [];
  const inviteList = Array.isArray(invitations.data) ? invitations.data : [];

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between gap-2">
        <h1 className="text-headline-md font-bold">{t("team")}</h1>
        <Sheet open={open} onOpenChange={setOpen}>
          <SheetTrigger render={<Button size="sm" />}>
            <Plus className="h-4 w-4" />
            {t("invite_admin")}
          </SheetTrigger>
          <SheetContent side="left" className="w-80 space-y-4">
            <SheetHeader>
              <SheetTitle>{t("invite_admin")}</SheetTitle>
            </SheetHeader>
            <div className="space-y-1.5">
              <Label>{t("email")}</Label>
              <Input value={email} onChange={(e) => setEmail(e.target.value)} />
            </div>
            <div className="space-y-1.5">
              <Label>{t("role")}</Label>
              <Select
                value={role}
                onValueChange={(v) => setRole((v ?? "hr") as AdminRole)}
              >
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  {ROLES.map((r) => (
                    <SelectItem key={r} value={r}>
                      {t(ROLE_KEY[r])}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <SheetFooter>
              <SheetClose render={<Button variant="outline" />}>{t("cancel")}</SheetClose>
              <Button onClick={submit}>{t("send")}</Button>
            </SheetFooter>
          </SheetContent>
        </Sheet>
      </div>

      {inviteList.length > 0 && (
        <div className="rounded-lg border">
          <div className="border-b p-3 text-body-md font-medium">
            {t("invitation_pending")}
          </div>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>{t("email")}</TableHead>
                <TableHead>{t("invitation_code")}</TableHead>
                <TableHead>{t("actions")}</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {inviteList.map((inv) => (
                <TableRow key={inv.id}>
                  <TableCell>{inv.email}</TableCell>
                  <TableCell className="font-mono">{inv.code}</TableCell>
                  <TableCell>
                    <div className="flex gap-1">
                      <Button variant="ghost" size="sm" onClick={() => resend.mutate(inv.id)}>
                        {t("resend_invitation")}
                      </Button>
                      <Button variant="ghost" size="sm" onClick={() => cancel.mutate(inv.id)}>
                        {t("cancel_invitation")}
                      </Button>
                    </div>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </div>
      )}

      {admins.isLoading ? (
        <LoadingState />
      ) : admins.isError ? (
        <ErrorState onRetry={() => admins.refetch()} />
      ) : adminList.length === 0 ? (
        <EmptyState message={t("no_data")} />
      ) : (
        <div className="rounded-lg border">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>{t("name")}</TableHead>
                <TableHead>{t("email")}</TableHead>
                <TableHead>{t("role")}</TableHead>
                <TableHead>{t("status")}</TableHead>
                <TableHead>{t("actions")}</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {adminList.map((a) => (
                <TableRow key={a.id}>
                  <TableCell className="font-medium">{a.name}</TableCell>
                  <TableCell>{a.email}</TableCell>
                  <TableCell>{t(ROLE_KEY[a.role])}</TableCell>
                  <TableCell>
                    <Badge variant={a.is_active ? "default" : "secondary"}>
                      {a.is_active ? t("active") : t("suspended")}
                    </Badge>
                  </TableCell>
                  <TableCell>
                    <div className="flex gap-1">
                      {a.role !== "general_manager" && (
                        <Button variant="ghost" size="sm" onClick={() => setEditing(a.id)}>
                          {t("edit_permissions")}
                        </Button>
                      )}
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => setActive.mutate({ id: a.id, active: !a.is_active })}
                      >
                        {t("set_active")}
                      </Button>
                      {a.role !== "general_manager" && (
                        <Button variant="ghost" size="sm" onClick={() => remove.mutate(a.id)}>
                          {t("remove_admin")}
                        </Button>
                      )}
                    </div>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </div>
      )}

      <PermissionsEditor adminId={editing} onClose={() => setEditing(null)} />
    </div>
  );
}
