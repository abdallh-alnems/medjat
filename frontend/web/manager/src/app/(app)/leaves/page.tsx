"use client";

import { useState } from "react";
import { useT } from "@/lib/i18n/use-t";
import { useDebouncedCallback } from "@/lib/hooks/use-debounced";
import {
  useLeaves,
  useApproveLeave,
  useRejectLeave,
} from "@/lib/hooks/use-leaves";
import { useBranches, useCategories } from "@/lib/hooks/use-org";
import {
  LoadingState,
  ErrorState,
  EmptyState,
} from "@/components/ui/states";
import { Input } from "@/components/ui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { LeaveRow } from "@/components/leave/leave-row";
import { AddLeaveSheet } from "@/components/leave/add-leave-sheet";
import { CalendarDays, Search } from "lucide-react";
import type { TKey } from "@/lib/i18n/ar";

const STATUSES = ["pending", "approved", "rejected"] as const;

export default function LeavesPage() {
  const { t } = useT();
  const { data: branches } = useBranches();
  const { data: categories } = useCategories();
  const [status, setStatus] = useState("all");
  const [branchId, setBranchId] = useState<number | undefined>(undefined);
  const [categoryId, setCategoryId] = useState<number | undefined>(undefined);
  const [search, setSearch] = useState("");
  const onSearch = useDebouncedCallback((v: string) => setSearch(v), 300);

  const { data, isLoading, isError, refetch } = useLeaves({
    status: status === "all" ? undefined : status,
    branch_id: branchId,
    category_id: categoryId,
    q: search || undefined,
  });
  const approve = useApproveLeave();
  const reject = useRejectLeave();
  const rows = Array.isArray(data) ? data : [];

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between gap-2">
        <h1 className="text-headline-md font-bold">{t("leaves")}</h1>
        <AddLeaveSheet />
      </div>

      <div className="flex flex-wrap items-center gap-2">
        <div className="relative min-w-48 flex-1">
          <Search className="pointer-events-none absolute start-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            placeholder={t("search_employees")}
            className="ps-9"
            defaultValue={search}
            onChange={(e) => onSearch(e.target.value)}
          />
        </div>

        <Select value={status} onValueChange={(v) => setStatus(v ?? "all")}>
          <SelectTrigger className="w-40">
            <SelectValue>
              {(v) => (!v || v === "all" ? t("status") : t(v as TKey))}
            </SelectValue>
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">{t("all")}</SelectItem>
            {STATUSES.map((s) => (
              <SelectItem key={s} value={s}>
                {t(s as TKey)}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>

        <Select
          value={branchId ? String(branchId) : "all"}
          onValueChange={(v) =>
            setBranchId(!v || v === "all" ? undefined : Number(v))
          }
        >
          <SelectTrigger className="w-44">
            <SelectValue>
              {(v) =>
                !v || v === "all"
                  ? t("branch")
                  : (branches ?? []).find((b) => String(b.id) === v)?.name ??
                    String(v)
              }
            </SelectValue>
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">{t("all")}</SelectItem>
            {(branches ?? []).map((b) => (
              <SelectItem key={b.id} value={String(b.id)}>
                {b.name}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>

        <Select
          value={categoryId ? String(categoryId) : "all"}
          onValueChange={(v) =>
            setCategoryId(!v || v === "all" ? undefined : Number(v))
          }
        >
          <SelectTrigger className="w-44">
            <SelectValue>
              {(v) =>
                !v || v === "all"
                  ? t("category")
                  : (categories ?? []).find((c) => String(c.id) === v)?.name ??
                    String(v)
              }
            </SelectValue>
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">{t("all")}</SelectItem>
            {(categories ?? []).map((c) => (
              <SelectItem key={c.id} value={String(c.id)}>
                {c.name}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
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
