"use client";

import { useState } from "react";
import { useT } from "@/lib/i18n/use-t";
import {
  LoadingState,
  ErrorState,
} from "@/components/ui/states";
import { ReportPeriodSelector } from "./report-period-selector";
import { ReportTable } from "./report-table";
import { ReportExport } from "./report-export";
import { Button } from "@/components/ui/button";
import { useQuery } from "@tanstack/react-query";
import { todayISO } from "@/lib/utils";
import type { TKey } from "@/lib/i18n/ar";
import type { ReportData } from "@/lib/types";

interface Props {
  titleKey: TKey;
  fetcher: (params: { from: string; to: string }) => Promise<ReportData>;
}

/** Generic report page: period picker + generate + table + export. */
export function GenericReportPage({ titleKey, fetcher }: Props) {
  const { t } = useT();
  const [from, setFrom] = useState(todayISO().slice(0, 8) + "01");
  const [to, setTo] = useState(todayISO());
  const [enabled, setEnabled] = useState(false);

  const { data, isLoading, isError, refetch } = useQuery({
    queryKey: ["reports", titleKey, from, to],
    queryFn: () => fetcher({ from, to }),
    enabled,
  });

  return (
    <div className="space-y-4">
      <h1 className="text-headline-md font-bold">{t(titleKey)}</h1>

      <div className="flex flex-wrap items-end gap-3">
        <ReportPeriodSelector
          from={from}
          to={to}
          onFromChange={setFrom}
          onToChange={setTo}
        />
        <Button
          onClick={() => {
            setEnabled(true);
            refetch();
          }}
        >
          {t("generate_report")}
        </Button>
        {enabled && <ReportExport report={data} />}
      </div>

      {enabled ? (
        isLoading ? (
          <LoadingState />
        ) : isError ? (
          <ErrorState onRetry={() => refetch()} />
        ) : (
          <ReportTable report={data} />
        )
      ) : null}
    </div>
  );
}
