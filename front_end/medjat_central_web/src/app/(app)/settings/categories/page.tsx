"use client";

import { useState } from "react";
import Link from "next/link";
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
  const [color, setColor] = useState("#3b82f6");
  const [description, setDescription] = useState("");

  const create = useToastMutation(
    () => createCategory(name, color, description || undefined),
    {
      successMessage: t("success"),
      invalidate: [["org", "categories"] as const],
      onSuccess: () => {
        setName("");
        setDescription("");
      },
    },
  );
  const remove = useToastMutation((id: number) => deleteCategory(id), {
    invalidate: [["org", "categories"] as const],
  });

  return (
    <div className="space-y-4">
      <h1 className="text-headline-md font-bold">{t("categories")}</h1>

      <Card>
        <CardContent className="space-y-3 p-4">
          <div className="grid gap-3 sm:grid-cols-[1fr_auto]">
            <div className="space-y-1.5">
              <Label>{t("name")}</Label>
              <Input value={name} onChange={(e) => setName(e.target.value)} />
            </div>
            <div className="space-y-1.5">
              <Label>{t("color")}</Label>
              <Input
                type="color"
                value={color}
                onChange={(e) => setColor(e.target.value)}
                className="h-10 w-16 p-1"
              />
            </div>
          </div>
          <div className="space-y-1.5">
            <Label>
              {t("description")} ({t("optional")})
            </Label>
            <Input
              value={description}
              onChange={(e) => setDescription(e.target.value)}
            />
          </div>
          <Button
            onClick={() => create.mutate(undefined)}
            disabled={!name || create.isPending}
          >
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
              <Link
                href={`/settings/categories/${c.id}`}
                className="flex min-w-0 flex-1 items-center gap-2 font-medium hover:underline"
              >
                <span className="truncate">{c.name}</span>
                {c.member_count != null && (
                  <span className="text-label-sm text-muted-foreground">
                    ({c.member_count})
                  </span>
                )}
              </Link>
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
