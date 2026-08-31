"use client";

import { Loader2, AlertCircle, Inbox } from "lucide-react";
import { Button } from "@/components/ui/button";
import { useT } from "@/lib/i18n/use-t";

export function LoadingState({ label }: { label?: string }) {
  const { t } = useT();
  return (
    <div className="flex flex-col items-center justify-center gap-3 py-16 text-muted-foreground">
      <Loader2 className="h-6 w-6 animate-spin" />
      <p className="text-body-md">{label ?? t("loading")}</p>
    </div>
  );
}

export function EmptyState({
  message,
  icon: Icon = Inbox,
}: {
  message?: string;
  icon?: React.ElementType;
}) {
  const { t } = useT();
  return (
    <div className="flex flex-col items-center justify-center gap-3 py-16 text-muted-foreground">
      <Icon className="h-10 w-10 opacity-50" />
      <p className="text-body-md">{message ?? t("no_data")}</p>
    </div>
  );
}

export function ErrorState({
  message,
  onRetry,
}: {
  message?: string;
  onRetry?: () => void;
}) {
  const { t } = useT();
  return (
    <div className="flex flex-col items-center justify-center gap-3 py-16 text-destructive">
      <AlertCircle className="h-10 w-10" />
      <p className="text-body-md">{message ?? t("error_loading")}</p>
      {onRetry && (
        <Button variant="outline" onClick={onRetry}>
          {t("retry")}
        </Button>
      )}
    </div>
  );
}
