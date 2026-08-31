"use client";

import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useT } from "@/lib/i18n/use-t";

interface Props {
  from: string;
  to: string;
  onFromChange: (v: string) => void;
  onToChange: (v: string) => void;
}

/** From/To period picker used by all report pages. */
export function ReportPeriodSelector({
  from,
  to,
  onFromChange,
  onToChange,
}: Props) {
  const { t } = useT();
  return (
    <div className="flex items-end gap-3">
      <div className="space-y-1.5">
        <Label>{t("from")}</Label>
        <Input type="date" value={from} onChange={(e) => onFromChange(e.target.value)} className="w-44" />
      </div>
      <div className="space-y-1.5">
        <Label>{t("to")}</Label>
        <Input type="date" value={to} onChange={(e) => onToChange(e.target.value)} className="w-44" />
      </div>
    </div>
  );
}
