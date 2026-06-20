"use client";

import { useState } from "react";
import { useT } from "@/lib/i18n/use-t";
import {
  listAssets,
  createAsset,
  deleteAsset,
  approveReturn,
  rejectReturn,
} from "@/lib/api/categories";
import { useToastMutation } from "@/lib/hooks/use-org";
import { useQuery } from "@tanstack/react-query";
import { LoadingState, ErrorState, EmptyState } from "@/components/ui/states";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Plus, Boxes } from "lucide-react";
import type { AssetCustody, AssetStatus } from "@/lib/types";
import type { TKey } from "@/lib/i18n/ar";

const STATUS_KEY: Record<AssetStatus, TKey> = {
  assigned: "assigned",
  return_requested: "return_requested",
  returned: "returned",
};

export default function AssetsSettingsPage() {
  const { t } = useT();
  const { data, isLoading, isError, refetch } = useQuery({
    queryKey: ["settings", "assets"],
    queryFn: listAssets,
  });
  const rows: AssetCustody[] = Array.isArray(data) ? data : [];

  const [name, setName] = useState("");
  const [value, setValue] = useState("");

  const create = useToastMutation(
    (args: { name: string; value: number }) =>
      createAsset({ name: args.name, value: args.value }),
    {
      invalidate: [["settings", "assets"] as const],
      onSuccess: () => {
        setName("");
        setValue("");
      },
    },
  );
  const remove = useToastMutation(
    (id: number) => deleteAsset(id),
    { invalidate: [["settings", "assets"] as const] },
  );
  const approve = useToastMutation(
    (id: number) => approveReturn(id),
    { invalidate: [["settings", "assets"] as const] },
  );
  const reject = useToastMutation(
    (id: number) => rejectReturn(id),
    { invalidate: [["settings", "assets"] as const] },
  );

  return (
    <div className="space-y-4">
      <h1 className="text-headline-md font-bold">{t("assets")}</h1>

      <Card>
        <CardContent className="flex items-end gap-3 p-4">
          <div className="flex-1 space-y-1.5">
            <Label>{t("asset_name")}</Label>
            <Input value={name} onChange={(e) => setName(e.target.value)} />
          </div>
          <div className="w-32 space-y-1.5">
            <Label>{t("asset_value")}</Label>
            <Input
              type="number"
              value={value}
              onChange={(e) => setValue(e.target.value)}
            />
          </div>
          <Button
            onClick={() => create.mutate({ name, value: Number(value) || 0 })}
            disabled={!name || create.isPending}
          >
            <Plus className="h-4 w-4" />
            {t("add_asset")}
          </Button>
        </CardContent>
      </Card>

      {isLoading ? (
        <LoadingState />
      ) : isError ? (
        <ErrorState onRetry={() => refetch()} />
      ) : rows.length === 0 ? (
        <EmptyState message={t("no_data")} icon={Boxes} />
      ) : (
        <div className="rounded-lg border">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>{t("name")}</TableHead>
                <TableHead>{t("status")}</TableHead>
                <TableHead>{t("asset_value")}</TableHead>
                <TableHead>{t("actions")}</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {rows.map((a) => (
                <TableRow key={a.id}>
                  <TableCell className="font-medium">{a.name}</TableCell>
                  <TableCell>
                    <Badge variant="outline">{t(STATUS_KEY[a.status])}</Badge>
                  </TableCell>
                  <TableCell>{a.value ?? "—"}</TableCell>
                  <TableCell>
                    <div className="flex gap-1">
                      {a.status === "return_requested" && (
                        <>
                          <Button variant="ghost" size="sm" onClick={() => approve.mutate(a.id)}>
                            {t("approve_return")}
                          </Button>
                          <Button variant="ghost" size="sm" onClick={() => reject.mutate(a.id)}>
                            {t("reject_return")}
                          </Button>
                        </>
                      )}
                      <Button variant="ghost" size="sm" onClick={() => remove.mutate(a.id)}>
                        {t("delete")}
                      </Button>
                    </div>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </div>
      )}
    </div>
  );
}
