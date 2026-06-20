"use client";

import { Sheet, SheetContent, SheetHeader, SheetTitle, SheetTrigger } from "@/components/ui/sheet";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { SlidersHorizontal } from "lucide-react";
import { useT } from "@/lib/i18n/use-t";
import { useBranches, useShifts, useCategories } from "@/lib/hooks/use-org";
import type { EmployeeListParams } from "@/lib/api/employees";

export const STATUS_TONE: Record<string, "default" | "secondary" | "destructive" | "outline"> = {
  active: "default",
  suspended: "secondary",
  terminated: "destructive",
};

interface Props {
  filters: EmployeeListParams;
  onChange: (next: EmployeeListParams) => void;
}

export function FiltersSheet({ filters, onChange }: Props) {
  const { t } = useT();
  const { data: branches } = useBranches();
  const { data: shifts } = useShifts();
  const { data: categories } = useCategories();

  return (
    <Sheet>
      <SheetTrigger
        render={<Button variant="outline" size="sm" />}
      >
        <SlidersHorizontal className="h-4 w-4" />
        {t("filter")}
      </SheetTrigger>
      <SheetContent side="left" className="w-80 space-y-4">
        <SheetHeader>
          <SheetTitle>{t("filter")}</SheetTitle>
        </SheetHeader>

        <div className="space-y-1.5">
          <Label>{t("branch")}</Label>
          <Select
            value={filters.branch_id ? String(filters.branch_id) : "all"}
            onValueChange={(v) =>
              onChange({ ...filters, branch_id: !v || v === "all" ? undefined : Number(v) })
            }
          >
            <SelectTrigger><SelectValue /></SelectTrigger>
            <SelectContent>
              <SelectItem value="all">{t("all")}</SelectItem>
              {(branches ?? []).map((b) => (
                <SelectItem key={b.id} value={String(b.id)}>{b.name}</SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>

        <div className="space-y-1.5">
          <Label>{t("shift")}</Label>
          <Select
            value={filters.shift_id ? String(filters.shift_id) : "all"}
            onValueChange={(v) =>
              onChange({ ...filters, shift_id: !v || v === "all" ? undefined : Number(v) })
            }
          >
            <SelectTrigger><SelectValue /></SelectTrigger>
            <SelectContent>
              <SelectItem value="all">{t("all")}</SelectItem>
              {(shifts ?? []).map((s) => (
                <SelectItem key={s.id} value={String(s.id)}>{s.name}</SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>

        <div className="space-y-1.5">
          <Label>{t("category")}</Label>
          <Select
            value={filters.category_id ? String(filters.category_id) : "all"}
            onValueChange={(v) =>
              onChange({ ...filters, category_id: !v || v === "all" ? undefined : Number(v) })
            }
          >
            <SelectTrigger><SelectValue /></SelectTrigger>
            <SelectContent>
              <SelectItem value="all">{t("all")}</SelectItem>
              {(categories ?? []).map((c) => (
                <SelectItem key={c.id} value={String(c.id)}>{c.name}</SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>

        <div className="space-y-1.5">
          <Label>{t("status")}</Label>
          <Select
            value={filters.status ?? "all"}
            onValueChange={(v) =>
              onChange({ ...filters, status: !v || v === "all" ? undefined : v })
            }
          >
            <SelectTrigger><SelectValue /></SelectTrigger>
            <SelectContent>
              <SelectItem value="all">{t("all")}</SelectItem>
              <SelectItem value="active">{t("active")}</SelectItem>
              <SelectItem value="suspended">{t("suspended")}</SelectItem>
              <SelectItem value="terminated">{t("terminated")}</SelectItem>
            </SelectContent>
          </Select>
        </div>

        <Button
          variant="ghost"
          className="w-full"
          onClick={() =>
            onChange({ search: filters.search, page: 1, per_page: filters.per_page })
          }
        >
          {t("reset_permissions")}
        </Button>
      </SheetContent>
    </Sheet>
  );
}
