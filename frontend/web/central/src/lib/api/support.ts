import { apiClient, apiGet, apiPost, unwrapList } from "./client";
import type { SupportTicket, SupportMessage } from "@/lib/types";

export async function listTickets(): Promise<SupportTicket[]> {
  // Backend returns `{ tickets, total, page, unread_total }`.
  const raw = await apiGet<unknown>("v1/support/tickets");
  return unwrapList<SupportTicket>(raw, ["tickets", "items", "data"]);
}

export function createTicket(data: { subject: string; message: string }) {
  return apiPost<SupportTicket>("v1/support/tickets", data);
}

export async function listMessages(
  ticketId: number,
  afterId?: number,
): Promise<SupportMessage[]> {
  // Backend returns `{ ticket, messages, last_id }`.
  const raw = await apiGet<unknown>("v1/support/messages", {
    ticket_id: ticketId,
    after_id: afterId,
  });
  return unwrapList<SupportMessage>(raw, ["messages", "items", "data"]);
}

/**
 * Reply to a ticket, optionally with a screenshot.
 *
 * The attachment travels base64-encoded in the JSON body (the backend derives
 * its real type from the bytes and stores it outside any public directory), so
 * no multipart transport is needed. A reply may be an attachment with no text.
 */
export function replyTicket(
  ticketId: number,
  body: string,
  attachment?: { base64: string; name: string },
) {
  return apiPost<SupportMessage>("v1/support/reply", {
    ticket_id: ticketId,
    body,
    ...(attachment
      ? { attachment: attachment.base64, attachment_name: attachment.name }
      : {}),
  });
}

/**
 * Fetch an attachment as an object URL. Attachments are never public — the
 * request carries the session credentials like any other API call — so an
 * `<img src>` cannot load one directly.
 */
export async function fetchAttachment(messageId: number): Promise<string> {
  const res = await apiClient.get<Blob>("v1/support/attachment", {
    params: { message_id: messageId },
    responseType: "blob",
  });
  return URL.createObjectURL(res.data);
}

export function closeTicket(ticketId: number) {
  return apiPost<{ status?: string }>("v1/support/close", {
    ticket_id: ticketId,
  });
}
