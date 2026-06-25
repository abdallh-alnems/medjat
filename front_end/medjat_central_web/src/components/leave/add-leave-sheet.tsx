"use client";

import { useState } from "react";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetTrigger,
  SheetFooter,
  SheetClose,
} from "@/components/ui/sheet";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Checkbox } from "@/components/ui/checkbox";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Plus, Search, X } from "lucide-react";
import { useT } from "@/lib/i18n/use-t";
import { useCreateLeave } from "@/lib/hooks/use-leaves";
import { useEmployees } from "@/lib/hooks/use-employees";
import { useDebouncedCallback } from "@/lib/hooks/use-debounced";
import { todayISO } from "@/lib/utils";
import type { TKey } from "@/lib/i18n/ar";

// Leave types the backend accepts on create (create.php enum).
const LEAVE_TYPES = ["annual", "sick", "personal", "unpaid"] as const;

/** Sheet to create a leave request on behalf of an employee. */
export function AddLeaveSheet() {
  const { t } = useT();
  const [open, setOpen] = useState(false);
  const create = useCreateLeave();

  const [employeeId, setEmployeeId] = useState<number | null>(null);
  const [employeeName, setEmployeeName] = useState("");
  const [search, setSearch] = useState("");
  const onSearch = useDebouncedCallback((v: string) => setSearch(v), 300);

  const [type, setType] = useState("annual");
  const [singleDay, setSingleDay] = useState(true);
  const [from, setFrom] = useState(todayISO());
  const [to, setTo] = useState(todayISO());
  const [reason, setReason] = useState("");

  const employees = useEmployees(
    employeeId == null ? { search: search || undefined, per_page: 20 } : {},
  );
  const results = Array.isArray(employees.data)
    ? employees.data
    : employees.data?.data ?? [];

  const reset = () => {
    setEmployeeId(null);
    setEmployeeName("");
    setSearch("");
    setType("annual");
    setSingleDay(true);
    setFrom(todayISO());
    setTo(todayISO());
    setReason("");
  };

  const submit = () => {
    if (employeeId == null) return;
    create.mutate(
      {
        employee_id: employeeId,
        type,
        start_date: from,
        end_date: singleDay ? from : to,
        reason: reason.trim() || undefined,
      },
      {
        onSuccess: () => {
          reset();
          setOpen(false);
        },
      },
    );
  };

  return (
    <Sheet
      open={open}
      onOpenChange={(o) => {
        setOpen(o);
        if (!o) reset();
      }}
    >
      <SheetTrigger render={<Button size="sm" />}>
        <Plus className="h-4 w-4" />
        {t("new_leave")}
      </SheetTrigger>
      <SheetContent side="left" className="w-full max-w-sm space-y-4">
        <SheetHeader>
          <SheetTitle>{t("new_leave")}</SheetTitle>
        </SheetHeader>

        {/* Employee picker — search + pick (no manual id) */}
        <div className="space-y-1.5">
          <Label>{t("employee")}</Label>
          {employeeId != null ? (
            <div className="flex items-center justify-between rounded-lg border px-3 py-2">
              <span className="font-medium">{employeeName}</span>
              <Button
                variant="ghost"
                size="icon-sm"
                onClick={() => {
                  setEmployeeId(null);
                  setEmployeeName("");
                  setSearch("");
                }}
              >
                <X className="h-4 w-4" />
              </Button>
            </div>
          ) : (
            <>
              <div className="relative">
                <Search className="pointer-events-none absolute start-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
                <Input
                  placeholder={t("search_employees")}
                  className="ps-9"
                  defaultValue={search}
                  onChange={(e) => onSearch(e.target.value)}
                />
              </div>
              <div className="max-h-48 overflow-y-auto rounded-lg border">
                {results.length === 0 ? (
                  <p className="px-3 py-2 text-label-sm text-muted-foreground">
                    {t("no_employees")}
                  </p>
                ) : (
                  results.map((e) => (
                    <button
                      key={e.id}
                      type="button"
                      className="flex w-full items-center justify-between px-3 py-2 text-start text-body-md hover:bg-accent"
                      onClick={() => {
                        setEmployeeId(e.id);
                        setEmployeeName(e.name);
                      }}
                    >
                      <span>{e.name}</span>
                      {e.job_title && (
                        <span className="text-label-sm text-muted-foreground">
                          {e.job_title}
                        </span>
                      )}
                    </button>
                  ))
                )}
              </div>
            </>
          )}
        </div>

        {/* Leave type dropdown */}
        <div className="space-y-1.5">
          <Label>{t("leave_type")}</Label>
          <Select value={type} onValueChange={(v) => setType(v ?? "annual")}>
            <SelectTrigger className="w-full">
              <SelectValue>{(v) => t((v as string) as TKey)}</SelectValue>
            </SelectTrigger>
            <SelectContent>
              {LEAVE_TYPES.map((lt) => (
                <SelectItem key={lt} value={lt}>
                  {t(lt as TKey)}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>

        {/* Single day vs range */}
        <label className="flex items-center gap-2 text-body-md">
          <Checkbox
            checked={singleDay}
            onCheckedChange={(v) => setSingleDay(Boolean(v))}
          />
          {t("single_day")}
        </label>

        {singleDay ? (
          <div className="space-y-1.5">
            <Label>{t("date")}</Label>
            <Input
              type="date"
              value={from}
              onChange={(e) => setFrom(e.target.value)}
            />
          </div>
        ) : (
          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1.5">
              <Label>{t("from")}</Label>
              <Input
                type="date"
                value={from}
                onChange={(e) => setFrom(e.target.value)}
              />
            </div>
            <div className="space-y-1.5">
              <Label>{t("to")}</Label>
              <Input
                type="date"
                value={to}
                onChange={(e) => setTo(e.target.value)}
              />
            </div>
          </div>
        )}

        {/* Reason — optional */}
        <div className="space-y-1.5">
          <Label>
            {t("reason")}{" "}
            <span className="text-label-sm text-muted-foreground">
              ({t("optional")})
            </span>
          </Label>
          <Input value={reason} onChange={(e) => setReason(e.target.value)} />
        </div>

        <SheetFooter>
          <SheetClose render={<Button variant="outline" />}>
            {t("cancel")}
          </SheetClose>
          <Button
            onClick={submit}
            disabled={create.isPending || employeeId == null}
          >
            {create.isPending ? t("saving") : t("create")}
          </Button>
        </SheetFooter>
      </SheetContent>
    </Sheet>
  );
}
