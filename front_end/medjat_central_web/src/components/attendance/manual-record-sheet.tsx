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
import { Label } from "@/components/ui/label";
import { Input } from "@/components/ui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Plus } from "lucide-react";
import { useT } from "@/lib/i18n/use-t";
import { useManualCheckIn, useManualCheckInBatch } from "@/lib/hooks/use-attendance";
import { useToastMutation } from "@/lib/hooks/use-org";
import { toast } from "sonner";

const STATUSES = [
  "present",
  "absent",
  "late",
  "leave",
  "holiday",
] as const;

interface Props {
  date: string;
  employeeIds: number[];
  onDone?: () => void;
}

/** Sheet to record a single or batch manual attendance entry. */
export function ManualRecordSheet({ date, employeeIds, onDone }: Props) {
  const { t } = useT();
  const [open, setOpen] = useState(false);
  const single = useManualCheckIn();
  const batch = useManualCheckInBatch();

  const [employeeId, setEmployeeId] = useState<string>("");
  const [checkIn, setCheckIn] = useState("");
  const [checkOut, setCheckOut] = useState("");
  const [status, setStatus] = useState<string>("present");
  const [note, setNote] = useState("");

  const isBatch = employeeIds.length > 1;

  const reset = () => {
    setEmployeeId("");
    setCheckIn("");
    setCheckOut("");
    setStatus("present");
    setNote("");
  };

  const submit = useToastMutation(
    async () => {
      if (isBatch) {
        await batch.mutateAsync(
          employeeIds.map((id) => ({
            employee_id: id,
            date,
            status,
            check_in: checkIn || undefined,
            check_out: checkOut || undefined,
            note: note || undefined,
          })),
        );
      } else {
        await single.mutateAsync({
          employee_id: Number(employeeIds[0] ?? employeeId),
          date,
          status,
          check_in: checkIn || undefined,
          check_out: checkOut || undefined,
          note: note || undefined,
        });
      }
    },
    {
      successMessage: t("success"),
      onSuccess: () => {
        reset();
        setOpen(false);
        onDone?.();
      },
    },
  );

  return (
    <Sheet open={open} onOpenChange={setOpen}>
      <SheetTrigger render={<Button size="sm" />}>
        <Plus className="h-4 w-4" />
        {t("manual_record")}
      </SheetTrigger>
      <SheetContent side="left" className="w-80 space-y-4">
        <SheetHeader>
          <SheetTitle>
            {isBatch ? t("batch_record") : t("manual_record")}
          </SheetTitle>
        </SheetHeader>

        {!isBatch && (
          <div className="space-y-1.5">
            <Label>{t("employee")}</Label>
            <Input
              type="number"
              value={employeeId}
              onChange={(e) => setEmployeeId(e.target.value)}
              placeholder="ID"
            />
          </div>
        )}

        <div className="grid grid-cols-2 gap-3">
          <div className="space-y-1.5">
            <Label>{t("check_in_time")}</Label>
            <Input
              type="time"
              value={checkIn}
              onChange={(e) => setCheckIn(e.target.value)}
            />
          </div>
          <div className="space-y-1.5">
            <Label>{t("check_out_time")}</Label>
            <Input
              type="time"
              value={checkOut}
              onChange={(e) => setCheckOut(e.target.value)}
            />
          </div>
        </div>

        <div className="space-y-1.5">
          <Label>{t("status")}</Label>
          <Select value={status} onValueChange={(v) => setStatus(v ?? "present")}>
            <SelectTrigger>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {STATUSES.map((s) => (
                <SelectItem key={s} value={s}>
                  {t(s)}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>

        <div className="space-y-1.5">
          <Label>{t("note")}</Label>
          <Input value={note} onChange={(e) => setNote(e.target.value)} />
        </div>

        <SheetFooter>
          <SheetClose render={<Button variant="outline" />}>
            {t("cancel")}
          </SheetClose>
          <Button
            onClick={() => submit.mutate(undefined)}
            disabled={submit.isPending || (!isBatch && !employeeId)}
          >
            {submit.isPending ? t("saving") : t("save")}
          </Button>
        </SheetFooter>
      </SheetContent>
    </Sheet>
  );
}
