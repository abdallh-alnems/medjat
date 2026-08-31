"use client";

import { useState } from "react";
import { useT } from "@/lib/i18n/use-t";
import {
  useStatutoryPayroll,
  useUpdateStatutoryPayroll,
} from "@/lib/hooks/use-settings";
import type { StatutoryPayroll, TaxBracket } from "@/lib/api/settings";
import { LoadingState, ErrorState } from "@/components/ui/states";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Checkbox } from "@/components/ui/checkbox";
import { Plus, Trash2 } from "lucide-react";

export default function StatutoryPayrollPage() {
  const { data, isLoading, isError, refetch } = useStatutoryPayroll();
  if (isLoading) return <LoadingState />;
  if (isError || !data) return <ErrorState onRetry={() => refetch()} />;
  return <StatutoryForm initial={data} />;
}

function StatutoryForm({ initial }: { initial: StatutoryPayroll }) {
  const { t } = useT();
  const update = useUpdateStatutoryPayroll();
  const [form, setForm] = useState<StatutoryPayroll>(() => ({
    ...initial,
    income_tax_brackets: initial.income_tax_brackets ?? [],
  }));

  const set = <K extends keyof StatutoryPayroll>(
    k: K,
    v: StatutoryPayroll[K],
  ) => setForm((f) => ({ ...f, [k]: v }));

  const numOrNull = (v: string) => (v === "" ? null : Number(v));

  const setBracket = (i: number, patch: Partial<TaxBracket>) =>
    setForm((f) => ({
      ...f,
      income_tax_brackets: f.income_tax_brackets.map((b, idx) =>
        idx === i ? { ...b, ...patch } : b,
      ),
    }));

  const addBracket = () =>
    setForm((f) => ({
      ...f,
      income_tax_brackets: [...f.income_tax_brackets, { up_to: null, rate: 0 }],
    }));

  const removeBracket = (i: number) =>
    setForm((f) => ({
      ...f,
      income_tax_brackets: f.income_tax_brackets.filter((_, idx) => idx !== i),
    }));

  return (
    <div className="mx-auto max-w-2xl space-y-4">
      <div>
        <h1 className="text-headline-md font-bold">{t("statutory_payroll")}</h1>
        <p className="mt-1 text-body-md text-muted-foreground">
          {t("statutory_intro")}
        </p>
      </div>

      {/* ── Social insurance ── */}
      <Card>
        <CardHeader>
          <CardTitle>{t("social_insurance")}</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <label className="flex items-center gap-2 text-body-md">
            <Checkbox
              checked={form.social_insurance_enabled}
              onCheckedChange={(v) =>
                set("social_insurance_enabled", Boolean(v))
              }
            />
            {t("enable_social_insurance")}
          </label>
          {form.social_insurance_enabled && (
            <div className="grid gap-3 border-s ps-3 sm:grid-cols-3">
              <div className="space-y-1.5">
                <Label>{t("si_employee_rate")}</Label>
                <Input
                  type="number"
                  value={form.si_employee_rate ?? ""}
                  onChange={(e) =>
                    set("si_employee_rate", numOrNull(e.target.value))
                  }
                />
              </div>
              <div className="space-y-1.5">
                <Label>{t("si_min_wage")}</Label>
                <Input
                  type="number"
                  value={form.si_min_wage ?? ""}
                  onChange={(e) => set("si_min_wage", numOrNull(e.target.value))}
                />
              </div>
              <div className="space-y-1.5">
                <Label>{t("si_max_wage")}</Label>
                <Input
                  type="number"
                  value={form.si_max_wage ?? ""}
                  onChange={(e) => set("si_max_wage", numOrNull(e.target.value))}
                />
              </div>
            </div>
          )}
        </CardContent>
      </Card>

      {/* ── Income tax ── */}
      <Card>
        <CardHeader>
          <CardTitle>{t("income_tax")}</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <label className="flex items-center gap-2 text-body-md">
            <Checkbox
              checked={form.income_tax_enabled}
              onCheckedChange={(v) => set("income_tax_enabled", Boolean(v))}
            />
            {t("enable_income_tax")}
          </label>
          {form.income_tax_enabled && (
            <div className="space-y-4 border-s ps-3">
              <div className="space-y-1.5">
                <Label>{t("tax_personal_exemption")}</Label>
                <Input
                  type="number"
                  value={form.tax_personal_exemption ?? ""}
                  onChange={(e) =>
                    set("tax_personal_exemption", numOrNull(e.target.value))
                  }
                />
              </div>

              <div className="space-y-2">
                <Label>{t("income_tax_brackets")}</Label>
                {form.income_tax_brackets.map((b, i) => (
                  <div key={i} className="flex items-end gap-2">
                    <div className="flex-1 space-y-1">
                      <span className="text-xs text-muted-foreground">
                        {t("bracket_up_to")}
                      </span>
                      <Input
                        type="number"
                        placeholder={t("bracket_open_ended")}
                        value={b.up_to ?? ""}
                        onChange={(e) =>
                          setBracket(i, { up_to: numOrNull(e.target.value) })
                        }
                      />
                    </div>
                    <div className="w-24 space-y-1">
                      <span className="text-xs text-muted-foreground">
                        {t("bracket_rate")}
                      </span>
                      <Input
                        type="number"
                        value={b.rate}
                        onChange={(e) =>
                          setBracket(i, { rate: Number(e.target.value) || 0 })
                        }
                      />
                    </div>
                    <Button
                      type="button"
                      variant="ghost"
                      size="icon"
                      onClick={() => removeBracket(i)}
                    >
                      <Trash2 className="h-4 w-4" />
                    </Button>
                  </div>
                ))}
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  onClick={addBracket}
                >
                  <Plus className="h-4 w-4" />
                  {t("add_bracket")}
                </Button>
              </div>
            </div>
          )}
        </CardContent>
      </Card>

      {/* ── End of service benefit ── */}
      <Card>
        <CardHeader>
          <CardTitle>{t("eosb")}</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <label className="flex items-center gap-2 text-body-md">
            <Checkbox
              checked={form.eosb_enabled}
              onCheckedChange={(v) => set("eosb_enabled", Boolean(v))}
            />
            {t("enable_eosb")}
          </label>
          {form.eosb_enabled && (
            <div className="space-y-1.5 border-s ps-3">
              <Label>{t("eosb_days_per_year")}</Label>
              <Input
                type="number"
                value={form.eosb_days_per_year ?? ""}
                onChange={(e) =>
                  set("eosb_days_per_year", numOrNull(e.target.value))
                }
              />
            </div>
          )}
        </CardContent>
      </Card>

      <Button onClick={() => update.mutate(form)} disabled={update.isPending}>
        {update.isPending ? t("saving") : t("save_changes")}
      </Button>
    </div>
  );
}
