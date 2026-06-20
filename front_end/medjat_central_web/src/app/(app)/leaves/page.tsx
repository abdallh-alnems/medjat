"use client";

import { useT } from "@/lib/i18n/use-t";
import {
  useLeaves,
  useApproveLeave,
  useRejectLeave,
} from "@/lib/hooks/use-leaves";
import {
  LoadingState,
  ErrorState,
  EmptyState,
} from "@/components/ui/states";
import { LeaveRow } from "@/components/leave/leave-row";
import { AddLeaveSheet } from "@/components/leave/add-leave-sheet";
import { CalendarDays } from "lucide-react";

export default function LeavesPage() {
  const { t } = useT();
  const { data, isLoading, isError, refetch } = useLeaves();
  const approve = useApproveLeave();
  const reject = useRejectLeave();
  const rows = Array.isArray(data) ? data : [];

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between gap-2">
        <h1 className="text-headline-md font-bold">{t("leaves")}</h1>
        <AddLeaveSheet />
      </div>

      {isLoading ? (
        <LoadingState />
      ) : isError ? (
        <ErrorState onRetry={() => refetch()} />
      ) : rows.length === 0 ? (
        <EmptyState message={t("no_records")} icon={CalendarDays} />
      ) : (
        <LeaveRow
          rows={rows}
          onApprove={(id) => approve.mutate(id)}
          onReject={(id) => reject.mutate(id)}
        />
      )}
    </div>
  );
}
