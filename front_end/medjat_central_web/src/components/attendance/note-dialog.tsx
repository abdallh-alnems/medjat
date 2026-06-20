"use client";

import { useState, useEffect } from "react";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
  DialogTrigger,
  DialogClose,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Pencil } from "lucide-react";
import { useT } from "@/lib/i18n/use-t";
import { useUpdateNote } from "@/lib/hooks/use-attendance";
import { useToastMutation } from "@/lib/hooks/use-org";
import type { AttendanceRecord } from "@/lib/types";

interface Props {
  record: AttendanceRecord;
}

/** Dialog to add/edit/delete a record note. */
export function NoteDialog({ record }: Props) {
  const { t } = useT();
  const [open, setOpen] = useState(false);
  const [value, setValue] = useState(record.note ?? "");
  const mutate = useUpdateNote();

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setValue(record.note ?? "");
  }, [record.note]);

  const submit = useToastMutation(
    async () =>
      mutate.mutateAsync({
        employeeId: record.employee_id,
        date: record.date,
        note: value.trim() ? value.trim() : null,
      }),
    {
      successMessage: t("success"),
      onSuccess: () => setOpen(false),
    },
  );

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger
        render={
          <Button variant="ghost" size="icon-sm" aria-label={t("add_note")} />
        }
      >
        <Pencil className="h-4 w-4" />
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{record.note ? t("edit_note") : t("add_note")}</DialogTitle>
        </DialogHeader>
        <Textarea
          rows={4}
          value={value}
          onChange={(e) => setValue(e.target.value)}
          placeholder={t("notes")}
        />
        <DialogFooter>
          <DialogClose render={<Button variant="outline" />}>{t("cancel")}</DialogClose>
          <Button onClick={() => submit.mutate(undefined)} disabled={submit.isPending}>
            {submit.isPending ? t("saving") : t("save")}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
