"use client";

import { useState } from "react";
import Link from "next/link";
import { useT } from "@/lib/i18n/use-t";
import { useBranches } from "@/lib/hooks/use-org";
import { useToastMutation } from "@/lib/hooks/use-org";
import { createBranch, updateBranch } from "@/lib/api/branches";
import {
  LoadingState,
  ErrorState,
  EmptyState,
} from "@/components/ui/states";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { BranchLocationSheet } from "@/components/branch/branch-location-sheet";
import { Plus, QrCode, Building2 } from "lucide-react";
import type { Branch } from "@/lib/types";

export default function BranchesPage() {
  const { t } = useT();
  const { data, isLoading, isError, refetch } = useBranches();
  const branches = Array.isArray(data) ? data : [];
  const [name, setName] = useState("");

  const create = useToastMutation(
    (data: Partial<Branch>) => createBranch({ name: name || t("branch"), ...data }),
    { successMessage: t("success"), invalidate: [["org", "branches"] as const] },
  );

  const update = useToastMutation(
    (args: { id: number; data: Partial<Branch> }) =>
      updateBranch(args.id, args.data),
    { successMessage: t("success"), invalidate: [["org", "branches"] as const] },
  );

  return (
    <div className="space-y-4">
      <h1 className="text-headline-md font-bold">{t("branches")}</h1>

      <Card>
        <CardContent className="flex items-end gap-3 p-4">
          <div className="flex-1 space-y-1.5">
            <Label>{t("branch_name")}</Label>
            <Input value={name} onChange={(e) => setName(e.target.value)} />
          </div>
          <Button onClick={() => create.mutate({})} disabled={create.isPending}>
            <Plus className="h-4 w-4" />
            {t("add_branch")}
          </Button>
        </CardContent>
      </Card>

      {isLoading ? (
        <LoadingState />
      ) : isError ? (
        <ErrorState onRetry={() => refetch()} />
      ) : branches.length === 0 ? (
        <EmptyState message={t("no_data")} icon={Building2} />
      ) : (
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {branches.map((b) => (
            <Card key={b.id}>
              <CardContent className="space-y-3 p-4">
                <div className="flex items-start justify-between">
                  <div>
                    <p className="font-semibold">{b.name}</p>
                    {b.employee_count != null && (
                      <p className="text-xs text-muted-foreground">
                        {b.employee_count} {t("employees")}
                      </p>
                    )}
                  </div>
                  <Button
                    variant="ghost"
                    size="icon-sm"
                    render={<Link href={`/branches/${b.id}/qr`} />}
                    aria-label={t("qr_poster")}
                  >
                    <QrCode className="h-4 w-4" />
                  </Button>
                </div>
                <div className="text-xs text-muted-foreground">
                  {b.lat != null && b.lng != null
                    ? `${b.lat.toFixed(4)}, ${b.lng.toFixed(4)} (${b.radius}م)`
                    : t("branch_location")}
                </div>
                <BranchLocationSheet
                  branch={b}
                  onSave={(data) => update.mutate({ id: b.id, data })}
                />
              </CardContent>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
