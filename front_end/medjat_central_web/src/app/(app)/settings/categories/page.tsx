"use client";

import { useState } from "react";
import { useT } from "@/lib/i18n/use-t";
import { useCategories } from "@/lib/hooks/use-org";
import { useToastMutation } from "@/lib/hooks/use-org";
import { createCategory, deleteCategory } from "@/lib/api/categories";
import { LoadingState, ErrorState, EmptyState } from "@/components/ui/states";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Plus, Trash2, Tags } from "lucide-react";

export default function CategoriesSettingsPage() {
  const { t } = useT();
  const { data, isLoading, isError, refetch } = useCategories();
  const rows = Array.isArray(data) ? data : [];
  const [name, setName] = useState("");

  const create = useToastMutation((n: string) => createCategory(n), {
    successMessage: t("success"),
    invalidate: [["org", "categories"] as const],
    onSuccess: () => setName(""),
  });
  const remove = useToastMutation((id: number) => deleteCategory(id), {
    invalidate: [["org", "categories"] as const],
  });

  return (
    <div className="space-y-4">
      <h1 className="text-headline-md font-bold">{t("categories")}</h1>

      <Card>
        <CardContent className="flex items-end gap-3 p-4">
          <div className="flex-1 space-y-1.5">
            <Label>{t("name")}</Label>
            <Input value={name} onChange={(e) => setName(e.target.value)} />
          </div>
          <Button onClick={() => create.mutate(name)} disabled={!name}>
            <Plus className="h-4 w-4" />
            {t("add_category")}
          </Button>
        </CardContent>
      </Card>

      {isLoading ? (
        <LoadingState />
      ) : isError ? (
        <ErrorState onRetry={() => refetch()} />
      ) : rows.length === 0 ? (
        <EmptyState message={t("no_data")} icon={Tags} />
      ) : (
        <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
          {rows.map((c) => (
            <div
              key={c.id}
              className="flex items-center justify-between rounded-lg border p-3"
            >
              <span className="font-medium">{c.name}</span>
              <Button variant="ghost" size="icon-sm" onClick={() => remove.mutate(c.id)}>
                <Trash2 className="h-4 w-4" />
              </Button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
