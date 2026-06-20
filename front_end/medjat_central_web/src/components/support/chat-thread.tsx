"use client";

import { useState, useEffect, useRef } from "react";
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { useT } from "@/lib/i18n/use-t";
import {
  useTicketMessages,
  useReplyTicket,
} from "@/lib/hooks/use-support";
import { LoadingState, ErrorState, EmptyState } from "@/components/ui/states";
import { cn } from "@/lib/utils";
import type { SupportMessage } from "@/lib/types";

/** Chat thread for a ticket. Polls for new replies (15s). */
export function ChatThread({ ticketId }: { ticketId: number }) {
  const { t } = useT();
  const { data, isLoading, isError, refetch } = useTicketMessages(ticketId);
  const reply = useReplyTicket();
  const [body, setBody] = useState("");
  const endRef = useRef<HTMLDivElement>(null);

  const messages: SupportMessage[] = Array.isArray(data) ? data : [];

  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages.length]);

  const send = () => {
    if (!body.trim()) return;
    reply.mutate(
      { ticketId, body: body.trim() },
      { onSuccess: () => setBody("") },
    );
  };

  return (
    <div className="flex h-[60vh] flex-col rounded-lg border">
      <div className="flex-1 space-y-3 overflow-y-auto p-4">
        {isLoading ? (
          <LoadingState />
        ) : isError ? (
          <ErrorState onRetry={() => refetch()} />
        ) : messages.length === 0 ? (
          <EmptyState message={t("no_data")} />
        ) : (
          messages.map((m) => (
            <div
              key={m.id}
              className={cn(
                "max-w-[80%] rounded-lg p-3 text-body-md",
                m.sender === "user"
                  ? "ms-auto bg-primary text-primary-foreground"
                  : "me-auto bg-muted",
              )}
            >
              <ReactMarkdown remarkPlugins={[remarkGfm]}>
                {m.body}
              </ReactMarkdown>
              <p className="mt-1 text-xs opacity-70">{m.created_at}</p>
            </div>
          ))
        )}
        <div ref={endRef} />
      </div>

      <div className="flex items-end gap-2 border-t p-3">
        <Textarea
          rows={1}
          value={body}
          onChange={(e) => setBody(e.target.value)}
          placeholder={t("message")}
          className="min-h-9 flex-1 resize-none"
          onKeyDown={(e) => {
            if (e.key === "Enter" && !e.shiftKey) {
              e.preventDefault();
              send();
            }
          }}
        />
        <Button onClick={send} disabled={reply.isPending || !body.trim()}>
          {t("send")}
        </Button>
      </div>
    </div>
  );
}
