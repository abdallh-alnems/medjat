"use client";

import { useQuery } from "@tanstack/react-query";
import { useToastMutation } from "@/lib/hooks/use-org";
import {
  listTickets,
  createTicket,
  listMessages,
  replyTicket,
  closeTicket,
} from "@/lib/api/support";
import type { SupportMessage } from "@/lib/types";

const QK = ["support"] as const;

export function useTickets() {
  return useQuery({ queryKey: [...QK, "list"], queryFn: listTickets });
}

export function useTicketMessages(ticketId: number | null) {
  return useQuery({
    queryKey: [...QK, "messages", ticketId],
    queryFn: () => listMessages(ticketId as number),
    enabled: ticketId != null,
    // Poll for new replies (support chat).
    refetchInterval: 15_000,
  });
}

export function useCreateTicket() {
  return useToastMutation(
    (data: { subject: string; message: string }) => createTicket(data),
    { invalidate: [QK] },
  );
}

export function useReplyTicket() {
  return useToastMutation(
    (args: { ticketId: number; body: string }) =>
      replyTicket(args.ticketId, args.body),
    { invalidate: [[...QK, "messages"] as const] },
  );
}

export function useCloseTicket() {
  return useToastMutation(
    (ticketId: number) => closeTicket(ticketId),
    { invalidate: [QK] },
  );
}

export type { SupportMessage };
