"use client";

import { useT } from "@/lib/i18n/use-t";
import { useToastMutation } from "@/lib/hooks/use-org";
import {
  listCarryoverPolicies,
  saveCarryoverPolicy,
  deleteCarryoverPolicy,
} from "@/lib/api/leaves";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { LoadingState, ErrorState, EmptyState } from "@/components/ui/states";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent } from "@/components/ui/card";
import { useState } from "react";
import type { CarryoverPolicy } from "@/lib/types";

export default function CarryoverPoliciesPage() {
  const { t } = useT();
  const qc = useQueryClient();
  const { data, isLoading, isError, refetch } = useQuery({
    queryKey: ["settings", "carryover"],
    queryFn: listCarryoverPolicies,
  });
  const rows = Array.isArray(data) ? data : [];

  const [max, setMax] = useState("0");
  const [encashable, setEncashable] = useState(false);

  const save = useToastMutation(
    (data: Partial<CarryoverPolicy>) =>
      saveCarryoverPolicy({
        max_carryover: Number(max) || 0,
        encashable,
        ...data,
      }),
    {
      invalidate: [["settings", "carryover"] as const],
      onSuccess: () => {
        setMax("0");
        setEncashable(false);
      },
    },
  );

  const remove = useToastMutation(
    (id: number) => deleteCarryoverPolicy(id),
    { invalidate: [["settings", "carryover"] as const] },
  );

  return (
    <div className="space-y-4">
      <h1 className="text-headline-md font-bold">{t("carryover_policy")}</h1>

      <Card>
        <CardContent className="flex items-end gap-3 p-4">
          <div className="space-y-1.5">
            <Label>{t("carryover")}</Label>
            <Input
              type="number"
              value={max}
              onChange={(e) => setMax(e.target.value)}
              className="w-32"
            />
          </div>
          <label className="flex items-center gap-2 text-body-md">
            <input
              type="checkbox"
              className="size-4"
              checked={encashable}
              onChange={(e) => setEncashable(e.target.checked)}
            />
            {t("encashment")}
          </label>
          <Button onClick={() => save.mutate({})}>{t("save")}</Button>
        </CardContent>
      </Card>

      {isLoading ? (
        <LoadingState />
      ) : isError ? (
        <ErrorState onRetry={() => refetch()} />
      ) : rows.length === 0 ? (
        <EmptyState />
      ) : (
        <div className="space-y-2">
          {rows.map((p) => (
            <div
              key={p.id}
              className="flex items-center justify-between rounded-lg border p-3"
            >
              <span>
                {t("carryover")}: {p.max_carryover}{" "}
                {p.encashable ? `· ${t("encashment")}` : ""}
              </span>
              <Button variant="ghost" size="sm" onClick={() => remove.mutate(p.id)}>
                {t("delete")}
              </Button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
