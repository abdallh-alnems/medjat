"use client";

import { useState, useEffect } from "react";
import { useT } from "@/lib/i18n/use-t";
import {
  useDeductionSettings,
  useSaveDeductionSettings,
} from "@/lib/hooks/use-settings";
import { LoadingState, ErrorState } from "@/components/ui/states";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Plus, Trash2 } from "lucide-react";
import type { DeductionRule } from "@/lib/types";

export default function DeductionsSettingsPage() {
  const { t } = useT();
  const { data, isLoading, isError, refetch } = useDeductionSettings();
  const save = useSaveDeductionSettings();
  const [rules, setRules] = useState<DeductionRule[]>([]);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    if (Array.isArray(data)) setRules(data);
  }, [data]);

  if (isLoading) return <LoadingState />;
  if (isError) return <ErrorState onRetry={() => refetch()} />;

  const update = (id: number, patch: Partial<DeductionRule>) =>
    setRules((rs) => rs.map((r) => (r.id === id ? { ...r, ...patch } : r)));
  const add = () =>
    setRules((rs) => [
      ...rs,
      { id: Date.now(), name: "", amount: 0, active: true },
    ]);
  const remove = (id: number) =>
    setRules((rs) => rs.filter((r) => r.id !== id));

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t("deductions_settings")}</CardTitle>
      </CardHeader>
      <CardContent className="space-y-3">
        {rules.map((r) => (
          <div key={r.id} className="flex items-end gap-2">
            <div className="flex-1 space-y-1.5">
              <Label>{t("name")}</Label>
              <Input
                value={r.name}
                onChange={(e) => update(r.id, { name: e.target.value })}
              />
            </div>
            <div className="w-32 space-y-1.5">
              <Label>{t("amount")}</Label>
              <Input
                type="number"
                value={r.amount}
                onChange={(e) => update(r.id, { amount: Number(e.target.value) })}
              />
            </div>
            <Button variant="ghost" size="icon" onClick={() => remove(r.id)}>
              <Trash2 className="h-4 w-4" />
            </Button>
          </div>
        ))}
        <Button variant="outline" onClick={add}>
          <Plus className="h-4 w-4" />
          {t("add")}
        </Button>
        <div>
          <Button
            onClick={() => save.mutate(rules)}
            disabled={save.isPending}
          >
            {save.isPending ? t("saving") : t("save")}
          </Button>
        </div>
      </CardContent>
    </Card>
  );
}
