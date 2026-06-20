"use client";

import { use } from "react";
import { useRouter } from "next/navigation";
import { useT } from "@/lib/i18n/use-t";
import {
  useTickets,
  useCloseTicket,
} from "@/lib/hooks/use-support";
import { ChatThread } from "@/components/support/chat-thread";
import { LoadingState, ErrorState, EmptyState } from "@/components/ui/states";
import { Button } from "@/components/ui/button";

export default function TicketChatPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = use(params);
  const ticketId = Number(id);
  const { t } = useT();
  const router = useRouter();
  const { data: tickets, isLoading, isError, refetch } = useTickets();
  const close = useCloseTicket();
  const ticket = (tickets ?? []).find((tk) => tk.id === ticketId) ?? null;

  if (isLoading) return <LoadingState />;
  if (isError) return <ErrorState onRetry={() => refetch()} />;
  if (!ticket) return <EmptyState />;

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between gap-2">
        <h1 className="text-headline-md font-bold">{ticket.subject}</h1>
        {ticket.status === "open" && (
          <Button
            variant="outline"
            size="sm"
            onClick={() =>
              close.mutate(ticketId, {
                onSuccess: () => router.push("/support"),
              })
            }
          >
            {t("close_ticket")}
          </Button>
        )}
      </div>
      <ChatThread ticketId={ticketId} />
    </div>
  );
}
