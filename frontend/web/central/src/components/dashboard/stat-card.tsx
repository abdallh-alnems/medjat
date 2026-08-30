"use client";

import { cn } from "@/lib/utils";
import { formatNumber } from "@/lib/utils";
import { useUIStore } from "@/lib/stores/ui-store";
import type { LucideIcon } from "lucide-react";

interface StatCardProps {
  icon: LucideIcon;
  label: string;
  value: number | string;
  hint?: string;
  tone?: "default" | "success" | "warning" | "destructive";
}

const TONES: Record<NonNullable<StatCardProps["tone"]>, string> = {
  default: "bg-brand-subtle text-brand",
  success: "bg-success/15 text-success",
  warning: "bg-warning/15 text-warning",
  destructive: "bg-destructive/10 text-destructive",
};

export function StatCard({
  icon: Icon,
  label,
  value,
  hint,
  tone = "default",
}: StatCardProps) {
  const locale = useUIStore((s) => s.locale);
  const display =
    typeof value === "number" ? formatNumber(value, locale) : value;
  return (
    <div className="card-flat flex items-center gap-3">
      <div
        className={cn(
          "flex h-11 w-11 shrink-0 items-center justify-center rounded-xl",
          TONES[tone],
        )}
      >
        <Icon className="h-5 w-5" />
      </div>
      <div className="min-w-0">
        <p className="truncate text-label-md text-muted-foreground">{label}</p>
        <p className="text-headline-sm font-bold text-foreground">{display}</p>
        {hint && (
          <p className="text-label-sm text-muted-foreground">{hint}</p>
        )}
      </div>
    </div>
  );
}
