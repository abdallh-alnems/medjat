"use client";

import { use, useState } from "react";
import { useT } from "@/lib/i18n/use-t";
import { getBranch, generateBranchQr } from "@/lib/api/branches";
import { QrPoster } from "@/components/branch/qr-poster";
import { LoadingState, ErrorState, EmptyState } from "@/components/ui/states";
import { Button } from "@/components/ui/button";
import { useQuery } from "@tanstack/react-query";

export default function BranchQrPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = use(params);
  const numId = Number(id);
  const { t } = useT();

  const branch = useQuery({
    queryKey: ["org", "branches", numId],
    queryFn: () => getBranch(numId),
  });

  const [token, setToken] = useState<string | null>(null);
  const qr = useQuery({
    queryKey: ["org", "branches", numId, "qr"],
    queryFn: () => generateBranchQr(numId),
    enabled: false,
  });

  if (branch.isLoading) return <LoadingState />;
  if (branch.isError) return <ErrorState onRetry={() => branch.refetch()} />;
  if (!branch.data) return <EmptyState />;

  const resolvedToken = token ?? qr.data?.qr_token ?? "";

  return (
    <div className="space-y-4">
      <Button
        variant="outline"
        size="sm"
        onClick={() => void qr.refetch()}
        disabled={qr.isFetching}
      >
        {t("generate_qr")}
      </Button>
      {resolvedToken ? (
        <QrPoster branchName={branch.data.name} token={resolvedToken} />
      ) : (
        <EmptyState message={t("generate_qr")} />
      )}
    </div>
  );
}
