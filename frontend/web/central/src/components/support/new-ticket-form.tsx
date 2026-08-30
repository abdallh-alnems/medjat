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
import { Textarea } from "@/components/ui/textarea";
import { Plus } from "lucide-react";
import { useT } from "@/lib/i18n/use-t";
import { useCreateTicket } from "@/lib/hooks/use-support";

/** Sheet to create a new support ticket. */
export function NewTicketForm({ onCreated }: { onCreated?: () => void }) {
  const { t } = useT();
  const [open, setOpen] = useState(false);
  const create = useCreateTicket();
  const [subject, setSubject] = useState("");
  const [message, setMessage] = useState("");

  const submit = () => {
    create.mutate(
      { subject, message },
      {
        onSuccess: () => {
          setOpen(false);
          setSubject("");
          setMessage("");
          onCreated?.();
        },
      },
    );
  };

  return (
    <Sheet open={open} onOpenChange={setOpen}>
      <SheetTrigger render={<Button size="sm" />}>
        <Plus className="h-4 w-4" />
        {t("new_ticket")}
      </SheetTrigger>
      <SheetContent side="left" className="w-full max-w-sm space-y-4">
        <SheetHeader>
          <SheetTitle>{t("new_ticket")}</SheetTitle>
        </SheetHeader>
        <div className="space-y-1.5">
          <Label>{t("subject")}</Label>
          <Input value={subject} onChange={(e) => setSubject(e.target.value)} />
        </div>
        <div className="space-y-1.5">
          <Label>{t("message")}</Label>
          <Textarea
            rows={4}
            value={message}
            onChange={(e) => setMessage(e.target.value)}
          />
        </div>
        <SheetFooter>
          <SheetClose render={<Button variant="outline" />}>{t("cancel")}</SheetClose>
          <Button
            onClick={submit}
            disabled={create.isPending || !subject || !message}
          >
            {create.isPending ? t("saving") : t("send")}
          </Button>
        </SheetFooter>
      </SheetContent>
    </Sheet>
  );
}
