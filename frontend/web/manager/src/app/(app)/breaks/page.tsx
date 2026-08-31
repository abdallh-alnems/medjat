"use client";

import { useT } from "@/lib/i18n/use-t";
import {
  useBreaks,
  useApproveBreak,
  useRejectBreak,
  usePostponeBreak,
} from "@/lib/hooks/use-breaks";
import {
  LoadingState,
  ErrorState,
  EmptyState,
} from "@/components/ui/states";
import { BreakRow } from "@/components/leave/break-row";
import { Coffee } from "lucide-react";

export default function BreaksPage() {
  const { t } = useT();
  const { data, isLoading, isError, refetch } = useBreaks();
  const approve = useApproveBreak();
  const reject = useRejectBreak();
  const postpone = usePostponeBreak();
  const rows = Array.isArray(data) ? data : [];

  return (
    <div className="space-y-4">
      <h1 className="text-headline-md font-bold">{t("breaks")}</h1>

      {isLoading ? (
        <LoadingState />
      ) : isError ? (
        <ErrorState onRetry={() => refetch()} />
      ) : rows.length === 0 ? (
        <EmptyState message={t("no_records")} icon={Coffee} />
      ) : (
        <BreakRow
          rows={rows}
          onApprove={(id) => approve.mutate(id)}
          onReject={(id) => reject.mutate(id)}
          onPostpone={(id) => postpone.mutate(id)}
        />
      )}
    </div>
  );
}
