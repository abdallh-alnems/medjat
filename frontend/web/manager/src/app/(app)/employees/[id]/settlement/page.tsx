"use client";

import { use, useState } from "react";
import { useRouter, notFound } from "next/navigation";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useEmployee } from "@/lib/hooks/use-employees";
import {
  previewSettlement,
  saveSettlement,
  approveSettlement,
  markSettlementPaid,
} from "@/lib/api/settlements";
import { useToastMutation } from "@/lib/hooks/use-org";
import { useT } from "@/lib/i18n/use-t";
import { LoadingState } from "@/components/ui/states";
import { formatEGP } from "@/lib/utils";
import { useUIStore } from "@/lib/stores/ui-store";
import { Can } from "@/components/permissions/can";
import { todayISO } from "@/lib/utils";

export default function SettlementPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = use(params);
  const employeeId = Number(id);
  const router = useRouter();
  const { t } = useT();
  const locale = useUIStore((s) => s.locale);

  if (!id || Number.isNaN(employeeId)) notFound();

  const { data: employee } = useEmployee(employeeId);
  const [lastDay, setLastDay] = useState(todayISO());
  const [preview, setPreview] = useState<Awaited<ReturnType<typeof previewSettlement>> | null>(null);

  const previewMut = useToastMutation(
    (lwd: string) => previewSettlement(employeeId, lwd),
    {
      onSuccess: (data) => setPreview(data),
      successMessage: undefined,
    },
  );
  const saveMut = useToastMutation(
    (data: Parameters<typeof saveSettlement>[0]) => saveSettlement(data),
    {
      successMessage: t("saved"),
      onSuccess: () => router.push(`/employees/${employeeId}`),
    },
  );
  const approveMut = useToastMutation(
    (_: void) => approveSettlement(employeeId),
    { successMessage: t("approve"), onSuccess: () => setPreview(null) },
  );
  const paidMut = useToastMutation(
    (_: void) => markSettlementPaid(employeeId),
    { successMessage: t("mark_paid"), onSuccess: () => setPreview(null) },
  );

  return (
    <Can permission="manage_employees" fallback={<LoadingState />}>
      <div className="mx-auto max-w-xl space-y-4">
        <h1 className="text-headline-md font-bold">
          {t("settlement")} — {employee?.name ?? "…"}
        </h1>
        <Card>
          <CardHeader>
            <CardTitle className="text-title-lg">{t("preview_settlement")}</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="space-y-1.5">
              <Label>{t("last_working_day")}</Label>
              <Input
                type="date"
                value={lastDay}
                onChange={(e) => setLastDay(e.target.value)}
              />
            </div>
            <Button
              onClick={() => previewMut.mutate(lastDay)}
              disabled={previewMut.isPending}
            >
              {t("preview_settlement")}
            </Button>

            {preview && (
              <div className="card-flat space-y-2">
                <Row label={t("gratuity")} value={formatEGP(preview.gratuity, locale)} />
                <Row label={t("leave_encashment")} value={formatEGP(preview.leave_encashment, locale)} />
                <Row label={t("dues")} value={formatEGP(preview.dues, locale)} />
                <div className="border-t pt-2">
                  <Row label={t("total")} value={formatEGP(preview.total, locale)} bold />
                </div>
                <div className="flex flex-wrap gap-2 pt-2">
                  <Button
                    onClick={() =>
                      saveMut.mutate({ ...preview, employee_id: employeeId })
                    }
                    disabled={saveMut.isPending}
                  >
                    {t("save_settlement")}
                  </Button>
                  <Button variant="outline" onClick={() => approveMut.mutate()}>
                    {t("approve_settlement")}
                  </Button>
                  <Button variant="secondary" onClick={() => paidMut.mutate()}>
                    {t("mark_settlement_paid")}
                  </Button>
                </div>
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </Can>
  );
}

function Row({
  label,
  value,
  bold,
}: {
  label: string;
  value: string;
  bold?: boolean;
}) {
  return (
    <div className="flex items-center justify-between">
      <span className="text-body-md text-muted-foreground">{label}</span>
      <span className={bold ? "text-headline-sm font-bold" : "text-title-md font-semibold"}>
        {value}
      </span>
    </div>
  );
}
