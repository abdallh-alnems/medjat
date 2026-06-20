"use client";

import { useState } from "react";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetTrigger,
  SheetFooter,
  SheetClose,
} from "@/components/ui/sheet";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Checkbox } from "@/components/ui/checkbox";
import { Plus } from "lucide-react";
import { useT } from "@/lib/i18n/use-t";
import { useCreateLeave, useCreateRecurringLeave } from "@/lib/hooks/use-leaves";
import { todayISO } from "@/lib/utils";

/** Sheet to create a (optionally recurring) leave request on behalf of an employee. */
export function AddLeaveSheet() {
  const { t } = useT();
  const [open, setOpen] = useState(false);
  const create = useCreateLeave();
  const recurring = useCreateRecurringLeave();

  const [employeeId, setEmployeeId] = useState("");
  const [type, setType] = useState("annual");
  const [from, setFrom] = useState(todayISO());
  const [to, setTo] = useState(todayISO());
  const [reason, setReason] = useState("");
  const [isRecurring, setIsRecurring] = useState(false);

  const submit = () => {
    const data = {
      employee_id: Number(employeeId),
      type,
      from,
      to,
      reason: reason || undefined,
      recurring: isRecurring,
    };
    const mut = isRecurring ? recurring : create;
    mut.mutate(data, { onSuccess: () => setOpen(false) });
  };

  const pending = create.isPending || recurring.isPending;

  return (
    <Sheet open={open} onOpenChange={setOpen}>
      <SheetTrigger render={<Button size="sm" />}>
        <Plus className="h-4 w-4" />
        {t("new_leave")}
      </SheetTrigger>
      <SheetContent side="left" className="w-80 space-y-4">
        <SheetHeader>
          <SheetTitle>{t("new_leave")}</SheetTitle>
        </SheetHeader>

        <div className="space-y-1.5">
          <Label>{t("employee")}</Label>
          <Input
            type="number"
            value={employeeId}
            onChange={(e) => setEmployeeId(e.target.value)}
          />
        </div>
        <div className="space-y-1.5">
          <Label>{t("leave_type")}</Label>
          <Input value={type} onChange={(e) => setType(e.target.value)} />
        </div>
        <div className="grid grid-cols-2 gap-3">
          <div className="space-y-1.5">
            <Label>{t("from")}</Label>
            <Input type="date" value={from} onChange={(e) => setFrom(e.target.value)} />
          </div>
          <div className="space-y-1.5">
            <Label>{t("to")}</Label>
            <Input type="date" value={to} onChange={(e) => setTo(e.target.value)} />
          </div>
        </div>
        <div className="space-y-1.5">
          <Label>{t("reason")}</Label>
          <Input value={reason} onChange={(e) => setReason(e.target.value)} />
        </div>
        <label className="flex items-center gap-2 text-body-md">
          <Checkbox
            checked={isRecurring}
            onCheckedChange={(v) => setIsRecurring(Boolean(v))}
          />
          {t("recurring")}
        </label>

        <SheetFooter>
          <SheetClose render={<Button variant="outline" />}>{t("cancel")}</SheetClose>
          <Button onClick={submit} disabled={pending || !employeeId}>
            {pending ? t("saving") : t("create")}
          </Button>
        </SheetFooter>
      </SheetContent>
    </Sheet>
  );
}
