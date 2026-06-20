"use client";

import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { useT } from "@/lib/i18n/use-t";

interface Props {
  value: string;
  onChange: (v: string) => void;
}

export function SortMenu({ value, onChange }: Props) {
  const { t } = useT();
  return (
    <Select value={value} onValueChange={(v) => v && onChange(v)}>
      <SelectTrigger className="w-40">
        <SelectValue placeholder={t("sort_by")} />
      </SelectTrigger>
      <SelectContent>
        <SelectItem value="name">{t("sort_name")}</SelectItem>
        <SelectItem value="status">{t("sort_status")}</SelectItem>
        <SelectItem value="check_in">{t("sort_check_in")}</SelectItem>
      </SelectContent>
    </Select>
  );
}
