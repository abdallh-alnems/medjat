"use client";

import Link from "next/link";
import { Badge } from "@/components/ui/badge";
import { useUIStore } from "@/lib/stores/ui-store";
import { formatEGP } from "@/lib/utils";
import { useT } from "@/lib/i18n/use-t";
import type { Employee } from "@/lib/types";
import { STATUS_TONE } from "./filters-sheet";

export function EmployeeCard({ employee }: { employee: Employee }) {
  const { t } = useT();
  const locale = useUIStore((s) => s.locale);
  return (
    <Link
      href={`/employees/${employee.id}`}
      className="card-flat flex items-center justify-between transition-shadow hover:shadow-elev-md"
    >
      <div className="min-w-0">
        <p className="truncate font-semibold text-foreground">{employee.name}</p>
        <p className="text-label-sm text-muted-foreground">
          {employee.job_title ?? "—"} · {employee.code ?? "—"}
        </p>
        <p className="text-label-md text-muted-foreground">
          {formatEGP(employee.base_salary, locale)}
        </p>
      </div>
      <Badge variant={STATUS_TONE[employee.status] ?? "secondary"}>
        {t(employee.status as never)}
      </Badge>
    </Link>
  );
}
