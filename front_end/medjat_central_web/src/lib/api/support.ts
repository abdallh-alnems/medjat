import { apiGet, apiPost } from "./client";
import type { SupportTicket, SupportMessage } from "@/lib/types";

export function listTickets() {
  return apiGet<SupportTicket[]>("app/support/list.php");
}

export function createTicket(data: { subject: string; message: string }) {
  return apiPost<SupportTicket>("app/support/create.php", data);
}

export function listMessages(ticketId: number, afterId?: number) {
  return apiGet<SupportMessage[]>("app/support/messages.php", {
    ticket_id: ticketId,
    after_id: afterId,
  });
}

export function replyTicket(ticketId: number, body: string) {
  return apiPost<SupportMessage>("app/support/reply.php", {
    ticket_id: ticketId,
    body,
  });
}

export function closeTicket(ticketId: number) {
  return apiPost<{ status?: string }>("app/support/close.php", {
    ticket_id: ticketId,
  });
}
