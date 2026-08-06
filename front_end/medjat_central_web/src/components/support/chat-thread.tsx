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
import { fetchAttachment } from "@/lib/api/support";
import { LoadingState, ErrorState, EmptyState } from "@/components/ui/states";
import { cn } from "@/lib/utils";
import { Paperclip, X, FileText } from "lucide-react";
import { toast } from "sonner";
import type { SupportMessage } from "@/lib/types";

/** Screenshots and short PDFs only — the backend rejects anything larger. */
const MAX_ATTACHMENT_BYTES = 5 * 1024 * 1024;

/** Chat thread for a ticket. Polls for new replies (15s). */
export function ChatThread({ ticketId }: { ticketId: number }) {
  const { t } = useT();
  const { data, isLoading, isError, refetch } = useTicketMessages(ticketId);
  const reply = useReplyTicket();
  const [body, setBody] = useState("");
  const [attachment, setAttachment] = useState<{ base64: string; name: string } | null>(
    null,
  );
  const fileRef = useRef<HTMLInputElement>(null);
  const endRef = useRef<HTMLDivElement>(null);

  const messages: SupportMessage[] = Array.isArray(data) ? data : [];

  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages.length]);

  const pickFile = async (file: File) => {
    if (file.size > MAX_ATTACHMENT_BYTES) {
      toast.error("الحد الأقصى للمرفق ٥ ميجابايت");
      return;
    }
    const buffer = await file.arrayBuffer();
    const bytes = new Uint8Array(buffer);
    let binary = "";
    // Chunked to avoid blowing the argument limit on a multi-MB file.
    for (let i = 0; i < bytes.length; i += 0x8000) {
      binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
    }
    setAttachment({ base64: btoa(binary), name: file.name });
  };

  const send = () => {
    // A screenshot on its own is a complete report.
    if (!body.trim() && !attachment) return;
    reply.mutate(
      { ticketId, body: body.trim(), attachment: attachment ?? undefined },
      {
        onSuccess: () => {
          setBody("");
          setAttachment(null);
          if (fileRef.current) fileRef.current.value = "";
        },
      },
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
          messages.map((m) => {
            const fromUser = (m.sender ?? m.sender_type) === "user";
            return (
              <div
                key={m.id}
                className={cn(
                  "max-w-[80%] rounded-lg p-3 text-body-md",
                  fromUser
                    ? "ms-auto bg-primary text-primary-foreground"
                    : "me-auto bg-muted",
                )}
              >
                {m.body && (
                  <ReactMarkdown remarkPlugins={[remarkGfm]}>
                    {m.body}
                  </ReactMarkdown>
                )}
                {m.attachment_url && <Attachment message={m} />}
                <p className="mt-1 text-xs opacity-70">{m.created_at}</p>
              </div>
            );
          })
        )}
        <div ref={endRef} />
      </div>

      <div className="border-t p-3">
        {attachment && (
          <div className="mb-2 flex items-center gap-2 text-body-sm text-muted-foreground">
            <Paperclip className="size-4 shrink-0" />
            <span className="truncate">{attachment.name}</span>
            <Button
              variant="ghost"
              size="icon"
              className="size-6"
              onClick={() => {
                setAttachment(null);
                if (fileRef.current) fileRef.current.value = "";
              }}
              aria-label="إزالة المرفق"
            >
              <X className="size-4" />
            </Button>
          </div>
        )}
        <div className="flex items-end gap-2">
          <input
            ref={fileRef}
            type="file"
            accept="image/*,application/pdf"
            className="hidden"
            onChange={(e) => {
              const file = e.target.files?.[0];
              if (file) void pickFile(file);
            }}
          />
          <Button
            variant="outline"
            size="icon"
            onClick={() => fileRef.current?.click()}
            aria-label="إرفاق ملف"
          >
            <Paperclip className="size-4" />
          </Button>
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
          <Button
            onClick={send}
            disabled={reply.isPending || (!body.trim() && !attachment)}
          >
            {t("send")}
          </Button>
        </div>
      </div>
    </div>
  );
}

/**
 * One attachment. Fetched through the API (with credentials) into an object
 * URL, because attachments are not public files and an `<img src>` cannot
 * authenticate.
 */
function Attachment({ message }: { message: SupportMessage }) {
  const [url, setUrl] = useState<string | null>(null);
  const [failed, setFailed] = useState(false);
  const isImage = /\.(jpe?g|png|gif|webp)$/i.test(message.attachment_url ?? "");

  useEffect(() => {
    if (!isImage) return;
    let objectUrl: string | null = null;
    let cancelled = false;

    fetchAttachment(message.id)
      .then((value) => {
        if (cancelled) {
          URL.revokeObjectURL(value);
          return;
        }
        objectUrl = value;
        setUrl(value);
      })
      .catch(() => setFailed(true));

    return () => {
      cancelled = true;
      if (objectUrl) URL.revokeObjectURL(objectUrl);
    };
  }, [message.id, isImage]);

  const openInTab = async () => {
    try {
      const value = url ?? (await fetchAttachment(message.id));
      window.open(value, "_blank", "noopener");
    } catch {
      toast.error("تعذّر فتح المرفق");
    }
  };

  if (!isImage) {
    return (
      <button
        type="button"
        onClick={openInTab}
        className="mt-2 flex items-center gap-2 text-body-sm underline"
      >
        <FileText className="size-4" />
        {message.attachment_name ?? "مرفق"}
      </button>
    );
  }

  if (failed) {
    return <p className="mt-2 text-body-sm opacity-70">تعذّر تحميل المرفق</p>;
  }

  return url ? (
    // eslint-disable-next-line @next/next/no-img-element -- blob URL, not a remote asset
    <img
      src={url}
      alt={message.attachment_name ?? "مرفق"}
      onClick={openInTab}
      className="mt-2 max-h-64 cursor-zoom-in rounded-md"
    />
  ) : (
    <div className="mt-2 h-24 w-40 animate-pulse rounded-md bg-foreground/10" />
  );
}
