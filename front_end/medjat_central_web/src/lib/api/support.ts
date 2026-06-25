import { apiGet, apiPost, unwrapList } from "./client";
import type { SupportTicket, SupportMessage } from "@/lib/types";

export async function listTickets(): Promise<SupportTicket[]> {
  // Backend returns `{ tickets, total, page, unread_total }`.
  const raw = await apiGet<unknown>("app/support/list.php");
  return unwrapList<SupportTicket>(raw, ["tickets", "items", "data"]);
}

export function createTicket(data: { subject: string; message: string }) {
  return apiPost<SupportTicket>("app/support/create.php", data);
}

export async function listMessages(
  ticketId: number,
  afterId?: number,
): Promise<SupportMessage[]> {
  // Backend returns `{ ticket, messages, last_id }`.
  const raw = await apiGet<unknown>("app/support/messages.php", {
    ticket_id: ticketId,
    after_id: afterId,
  });
  return unwrapList<SupportMessage>(raw, ["messages", "items", "data"]);
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
