"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useT } from "@/lib/i18n/use-t";
import { useCreateBulkAdjustment } from "@/lib/hooks/use-bulk-adjustments";
import { useBranches, useShifts, useCategories } from "@/lib/hooks/use-org";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import type { AdjustmentType, AdjustmentScope } from "@/lib/types";

export default function NewBulkAdjustmentPage() {
  const { t } = useT();
  const router = useRouter();
  const create = useCreateBulkAdjustment();
  const { data: branches } = useBranches();
  const { data: shifts } = useShifts();
  const { data: categories } = useCategories();

  const [type, setType] = useState<AdjustmentType>("deduction");
  const [scope, setScope] = useState<AdjustmentScope>("all");
  const [amount, setAmount] = useState("");
  const [month, setMonth] = useState(new Date().toISOString().slice(0, 7));
  const [scopeId, setScopeId] = useState<string>("");

  const submit = () => {
    create.mutate(
      {
        type,
        scope,
        amount: Number(amount) || 0,
        month,
        members: scopeId ? [Number(scopeId)] : [],
      },
      { onSuccess: () => router.push("/payroll/bulk-adjustments") },
    );
  };

  return (
    <div className="mx-auto max-w-md space-y-4">
      <h1 className="text-headline-md font-bold">{t("new_bulk_adjustment")}</h1>

      <div className="space-y-1.5">
        <Label>{t("adjustment_type")}</Label>
        <Select value={type} onValueChange={(v) => setType((v ?? "deduction") as AdjustmentType)}>
          <SelectTrigger><SelectValue /></SelectTrigger>
          <SelectContent>
            <SelectItem value="deduction">{t("deduction")}</SelectItem>
            <SelectItem value="bonus">{t("bonus")}</SelectItem>
          </SelectContent>
        </Select>
      </div>

      <div className="space-y-1.5">
        <Label>{t("scope")}</Label>
        <Select value={scope} onValueChange={(v) => setScope((v ?? "all") as AdjustmentScope)}>
          <SelectTrigger><SelectValue /></SelectTrigger>
          <SelectContent>
            <SelectItem value="all">{t("all")}</SelectItem>
            <SelectItem value="branch">{t("branch")}</SelectItem>
            <SelectItem value="shift">{t("shift")}</SelectItem>
            <SelectItem value="category">{t("category")}</SelectItem>
          </SelectContent>
        </Select>
      </div>

      {scope !== "all" && (
        <div className="space-y-1.5">
          <Label>{t(scope === "branch" ? "branch" : scope === "shift" ? "shift" : "category")}</Label>
          <Select value={scopeId} onValueChange={(v) => setScopeId(v ?? "")}>
            <SelectTrigger><SelectValue /></SelectTrigger>
            <SelectContent>
              {(scope === "branch"
                ? branches ?? []
                : scope === "shift"
                  ? shifts ?? []
                  : categories ?? []
              ).map((o) => (
                <SelectItem key={o.id} value={String(o.id)}>
                  {o.name}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
      )}

      <div className="grid grid-cols-2 gap-3">
        <div className="space-y-1.5">
          <Label>{t("amount")}</Label>
          <Input
            type="number"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
          />
        </div>
        <div className="space-y-1.5">
          <Label>{t("month")}</Label>
          <Input type="month" value={month} onChange={(e) => setMonth(e.target.value)} />
        </div>
      </div>

      <div className="flex gap-2">
        <Button variant="outline" onClick={() => router.back()}>
          {t("cancel")}
        </Button>
        <Button onClick={submit} disabled={create.isPending}>
          {create.isPending ? t("saving") : t("create")}
        </Button>
      </div>
    </div>
  );
}
