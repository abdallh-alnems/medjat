"use client";

import { useState } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useT } from "@/lib/i18n/use-t";
import { useUIStore } from "@/lib/stores/ui-store";
import { useToastMutation } from "@/lib/hooks/use-org";
import {
  listAllowances,
  createAllowance,
  deleteAllowance,
} from "@/lib/api/allowances";
import { addManualDeduction, addManualBonus } from "@/lib/api/deductions";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { formatEGP, currentMonth } from "@/lib/utils";
import { Plus, Trash2 } from "lucide-react";

/** Recurring allowances + ad-hoc manual bonus/deduction management for an
 *  employee (mirrors the app's financial-tab adjustments). */
export function FinancialAdjustments({ employeeId }: { employeeId: number }) {
  const { t } = useT();
  const locale = useUIStore((s) => s.locale);
  const qc = useQueryClient();

  const allowances = useQuery({
    queryKey: ["allowances", employeeId],
    queryFn: () => listAllowances(employeeId),
  });

  const invalidate = () =>
    qc.invalidateQueries({ queryKey: ["allowances", employeeId] });

  const create = useToastMutation(
    (data: Parameters<typeof createAllowance>[0]) => createAllowance(data),
    { successMessage: t("saved"), onSuccess: invalidate },
  );
  const remove = useToastMutation((id: number) => deleteAllowance(id), {
    onSuccess: invalidate,
  });
  const addDeduction = useToastMutation(
    (data: { employee_id: number; amount: number; reason: string }) =>
      addManualDeduction(data),
    { successMessage: t("saved") },
  );
  const addBonus = useToastMutation(
    (data: { employee_id: number; amount: number; reason: string }) =>
      addManualBonus(data),
    { successMessage: t("saved") },
  );

  const list = Array.isArray(allowances.data) ? allowances.data : [];

  return (
    <div className="space-y-4">
      {/* ── Recurring allowances ── */}
      <Card>
        <CardHeader>
          <CardTitle className="text-title-lg">{t("allowances")}</CardTitle>
        </CardHeader>
        <CardContent className="space-y-3">
          {list.length === 0 ? (
            <p className="text-body-md text-muted-foreground">{t("no_data")}</p>
          ) : (
            <ul className="divide-y">
              {list.map((a) => (
                <li
                  key={a.id}
                  className="flex items-center justify-between py-2"
                >
                  <div>
                    <p className="flex items-center gap-2 font-medium">
                      {a.label || a.type}
                      {!a.active && (
                        <Badge variant="secondary">{t("inactive")}</Badge>
                      )}
                    </p>
                    <p className="text-label-sm text-muted-foreground">
                      {formatEGP(a.amount, locale)}
                      {a.start_month ? ` · ${a.start_month}` : ""}
                      {a.end_month ? ` → ${a.end_month}` : ""}
                    </p>
                  </div>
                  <Button
                    variant="ghost"
                    size="icon-sm"
                    onClick={() => remove.mutate(a.id)}
                  >
                    <Trash2 className="h-4 w-4" />
                  </Button>
                </li>
              ))}
            </ul>
          )}

          <AllowanceForm
            busy={create.isPending}
            onAdd={(v) =>
              create.mutate({ employee_id: employeeId, ...v })
            }
          />
        </CardContent>
      </Card>

      {/* ── Ad-hoc manual bonus / deduction ── */}
      <Card>
        <CardHeader>
          <CardTitle className="text-title-lg">
            {t("manual_bonus")} / {t("manual_deduction")}
          </CardTitle>
        </CardHeader>
        <CardContent className="grid gap-4 sm:grid-cols-2">
          <ManualForm
            label={t("add_bonus")}
            busy={addBonus.isPending}
            onAdd={(amount, reason) =>
              addBonus.mutate({ employee_id: employeeId, amount, reason })
            }
          />
          <ManualForm
            label={t("add_deduction")}
            busy={addDeduction.isPending}
            onAdd={(amount, reason) =>
              addDeduction.mutate({ employee_id: employeeId, amount, reason })
            }
          />
        </CardContent>
      </Card>
    </div>
  );
}

function AllowanceForm({
  onAdd,
  busy,
}: {
  onAdd: (v: {
    type: string;
    amount: number;
    start_month: string;
    end_month?: string | null;
  }) => void;
  busy: boolean;
}) {
  const { t } = useT();
  const [type, setType] = useState("");
  const [amount, setAmount] = useState("");
  const [startMonth, setStartMonth] = useState(() => currentMonth());
  const [endMonth, setEndMonth] = useState("");

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        if (!type.trim() || !amount) return;
        onAdd({
          type: type.trim(),
          amount: Number(amount),
          start_month: startMonth,
          end_month: endMonth || null,
        });
        setType("");
        setAmount("");
        setEndMonth("");
      }}
      className="grid gap-2 rounded-lg border p-3 sm:grid-cols-2"
    >
      <div className="space-y-1">
        <Label>{t("allowance_type")}</Label>
        <Input value={type} onChange={(e) => setType(e.target.value)} required />
      </div>
      <div className="space-y-1">
        <Label>{t("amount")}</Label>
        <Input
          type="number"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          required
        />
      </div>
      <div className="space-y-1">
        <Label>{t("start_month")}</Label>
        <Input
          type="month"
          value={startMonth}
          onChange={(e) => setStartMonth(e.target.value)}
        />
      </div>
      <div className="space-y-1">
        <Label>
          {t("end_month")} ({t("optional")})
        </Label>
        <Input
          type="month"
          value={endMonth}
          onChange={(e) => setEndMonth(e.target.value)}
        />
      </div>
      <div className="sm:col-span-2 flex justify-end">
        <Button type="submit" size="sm" disabled={busy}>
          <Plus className="h-4 w-4" />
          {t("add_allowance")}
        </Button>
      </div>
    </form>
  );
}

function ManualForm({
  label,
  onAdd,
  busy,
}: {
  label: string;
  onAdd: (amount: number, reason: string) => void;
  busy: boolean;
}) {
  const { t } = useT();
  const [amount, setAmount] = useState("");
  const [reason, setReason] = useState("");

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        if (!amount) return;
        onAdd(Number(amount), reason.trim());
        setAmount("");
        setReason("");
      }}
      className="space-y-2 rounded-lg border p-3"
    >
      <p className="font-medium">{label}</p>
      <div className="space-y-1">
        <Label>{t("amount")}</Label>
        <Input
          type="number"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          required
        />
      </div>
      <div className="space-y-1">
        <Label>{t("reason")}</Label>
        <Input value={reason} onChange={(e) => setReason(e.target.value)} />
      </div>
      <div className="flex justify-end">
        <Button type="submit" size="sm" disabled={busy}>
          {label}
        </Button>
      </div>
    </form>
  );
}
