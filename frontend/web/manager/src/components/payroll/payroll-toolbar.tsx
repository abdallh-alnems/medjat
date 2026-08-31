"use client";

import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover";
import { useT } from "@/lib/i18n/use-t";
import {
  Search,
  SlidersHorizontal,
  Layers,
  ArrowDownWideNarrow,
  ArrowUpNarrowWide,
} from "lucide-react";

export type SortKey = "name" | "net" | "deduction" | "bonus";
/** Two-state payroll filter: paid vs everything-else. */
export type StatusFilter = "paid" | "unpaid" | null;

interface NamedRef {
  id: number;
  name: string;
}

interface Props {
  search: string;
  onSearch: (v: string) => void;
  sortBy: SortKey;
  onSort: (v: SortKey) => void;
  sortAsc: boolean;
  onToggleDir: () => void;
  branchFilter: number | null;
  onBranch: (v: number | null) => void;
  shiftFilter: number | null;
  onShift: (v: number | null) => void;
  categoryFilter: number | null;
  onCategory: (v: number | null) => void;
  statusFilter: StatusFilter;
  onStatus: (v: StatusFilter) => void;
  groupByBranch: boolean;
  onToggleGroup: () => void;
  branches: NamedRef[];
  shifts: NamedRef[];
  categories: NamedRef[];
}

const ALL = "__all__";
const STATUSES: Exclude<StatusFilter, null>[] = ["unpaid", "paid"];

export function PayrollToolbar({
  search,
  onSearch,
  sortBy,
  onSort,
  sortAsc,
  onToggleDir,
  branchFilter,
  onBranch,
  shiftFilter,
  onShift,
  categoryFilter,
  onCategory,
  statusFilter,
  onStatus,
  groupByBranch,
  onToggleGroup,
  branches,
  shifts,
  categories,
}: Props) {
  const { t } = useT();

  const activeCount =
    (branchFilter !== null ? 1 : 0) +
    (shiftFilter !== null ? 1 : 0) +
    (categoryFilter !== null ? 1 : 0) +
    (statusFilter !== null ? 1 : 0);

  const statusLabel = (s: Exclude<StatusFilter, null>) =>
    s === "paid" ? t("status_disbursed") : t("status_not_disbursed");

  const sortLabel = (s: SortKey) =>
    s === "net"
      ? t("sort_net")
      : s === "deduction"
        ? t("sort_deduction")
        : s === "bonus"
          ? t("sort_bonus")
          : t("sort_name");

  const refSelect = (
    label: string,
    value: number | null,
    onChange: (v: number | null) => void,
    items: NamedRef[],
  ) => (
    <div className="space-y-1.5">
      <label className="text-xs text-muted-foreground">{label}</label>
      <Select
        value={value === null ? ALL : String(value)}
        onValueChange={(v) => onChange(v === ALL ? null : Number(v))}
      >
        <SelectTrigger className="w-full">
          <SelectValue>
            {(value: string) =>
              value === ALL
                ? t("all")
                : (items.find((it) => String(it.id) === value)?.name ??
                  t("all"))
            }
          </SelectValue>
        </SelectTrigger>
        <SelectContent>
          <SelectItem value={ALL}>{t("all")}</SelectItem>
          {items.map((it) => (
            <SelectItem key={it.id} value={String(it.id)}>
              {it.name}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    </div>
  );

  return (
    <div className="flex flex-wrap items-center gap-2">
      <div className="relative min-w-48 flex-1">
        <Search className="absolute start-2.5 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
        <Input
          value={search}
          onChange={(e) => onSearch(e.target.value)}
          placeholder={t("search_employees")}
          className="ps-8"
        />
      </div>

      <Select value={sortBy} onValueChange={(v) => onSort(v as SortKey)}>
        <SelectTrigger className="w-36">
          <SelectValue>
            {(value: string) => sortLabel(value as SortKey)}
          </SelectValue>
        </SelectTrigger>
        <SelectContent>
          <SelectItem value="name">{t("sort_name")}</SelectItem>
          <SelectItem value="net">{t("sort_net")}</SelectItem>
          <SelectItem value="deduction">{t("sort_deduction")}</SelectItem>
          <SelectItem value="bonus">{t("sort_bonus")}</SelectItem>
        </SelectContent>
      </Select>

      <Button
        variant="outline"
        size="sm"
        className="gap-1.5"
        onClick={onToggleDir}
        title={sortAsc ? t("sort_asc") : t("sort_desc")}
      >
        {sortAsc ? (
          <ArrowUpNarrowWide className="h-4 w-4" />
        ) : (
          <ArrowDownWideNarrow className="h-4 w-4" />
        )}
        {sortAsc ? t("sort_asc") : t("sort_desc")}
      </Button>

      <Popover>
        <PopoverTrigger
          render={<Button variant="outline" size="sm" className="gap-1.5" />}
        >
          <SlidersHorizontal className="h-4 w-4" />
          {t("filter")}
          {activeCount > 0 && (
            <Badge variant="secondary" className="ms-1">
              {activeCount}
            </Badge>
          )}
        </PopoverTrigger>
        <PopoverContent className="w-72 space-y-3">
          {refSelect(t("branch"), branchFilter, onBranch, branches)}
          {refSelect(t("shift"), shiftFilter, onShift, shifts)}
          {refSelect(t("category"), categoryFilter, onCategory, categories)}
          <div className="space-y-1.5">
            <label className="text-xs text-muted-foreground">{t("status")}</label>
            <Select
              value={statusFilter === null ? ALL : statusFilter}
              onValueChange={(v) =>
                onStatus(v === ALL ? null : (v as Exclude<StatusFilter, null>))
              }
            >
              <SelectTrigger className="w-full">
                <SelectValue>
                  {(value: string) =>
                    value === ALL
                      ? t("all")
                      : statusLabel(value as Exclude<StatusFilter, null>)
                  }
                </SelectValue>
              </SelectTrigger>
              <SelectContent>
                <SelectItem value={ALL}>{t("all")}</SelectItem>
                {STATUSES.map((s) => (
                  <SelectItem key={s} value={s}>
                    {statusLabel(s)}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          {activeCount > 0 && (
            <Button
              variant="ghost"
              size="sm"
              className="w-full"
              onClick={() => {
                onBranch(null);
                onShift(null);
                onCategory(null);
                onStatus(null);
              }}
            >
              {t("clear_filters")}
            </Button>
          )}
        </PopoverContent>
      </Popover>

      <Button
        variant={groupByBranch ? "default" : "outline"}
        size="sm"
        className="gap-1.5"
        onClick={onToggleGroup}
      >
        <Layers className="h-4 w-4" />
        {t("group_by_branch")}
      </Button>
    </div>
  );
}
