"use client";

import Link from "next/link";
import { Badge } from "@/components/ui/badge";
import { useT } from "@/lib/i18n/use-t";
import type { SupportTicket } from "@/lib/types";

/** A single support ticket row in the list. */
export function TicketRow({ ticket }: { ticket: SupportTicket }) {
  const { t } = useT();
  return (
    <Link
      href={`/support/${ticket.id}`}
      className="flex items-center justify-between rounded-lg border p-3 transition-colors hover:bg-muted/40"
    >
      <div className="min-w-0">
        <p className="truncate font-medium">{ticket.subject}</p>
        <p className="text-xs text-muted-foreground">{ticket.created_at}</p>
      </div>
      <Badge variant={ticket.status === "open" ? "default" : "secondary"}>
        {t(ticket.status === "open" ? "open" : "closed")}
      </Badge>
    </Link>
  );
}
