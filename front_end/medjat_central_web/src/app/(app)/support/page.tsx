"use client";

import { useT } from "@/lib/i18n/use-t";
import { useTickets } from "@/lib/hooks/use-support";
import { LoadingState, ErrorState, EmptyState } from "@/components/ui/states";
import { TicketRow } from "@/components/support/ticket-row";
import { NewTicketForm } from "@/components/support/new-ticket-form";
import { LifeBuoy } from "lucide-react";

export default function SupportPage() {
  const { t } = useT();
  const { data, isLoading, isError, refetch } = useTickets();
  const tickets = Array.isArray(data) ? data : [];

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between gap-2">
        <h1 className="text-headline-md font-bold">{t("support")}</h1>
        <NewTicketForm />
      </div>

      {isLoading ? (
        <LoadingState />
      ) : isError ? (
        <ErrorState onRetry={() => refetch()} />
      ) : tickets.length === 0 ? (
        <EmptyState message={t("no_data")} icon={LifeBuoy} />
      ) : (
        <div className="space-y-2">
          {tickets.map((tk) => (
            <TicketRow key={tk.id} ticket={tk} />
          ))}
        </div>
      )}
    </div>
  );
}
