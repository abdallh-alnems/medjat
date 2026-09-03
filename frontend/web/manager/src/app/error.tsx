"use client";

import { useEffect } from "react";
import { Button } from "@/components/ui/button";
import { AlertTriangle } from "lucide-react";

/**
 * Route-level error boundary (Next.js App Router). Logs the error (observability,
 * D14) and offers a retry. Must be a client component.
 */
export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    // Surface to console; a production logger can hook in here.
    console.error("[permedjat] route error:", error);
  }, [error]);

  return (
    <div className="flex flex-col items-center justify-center gap-4 py-20 text-center">
      <AlertTriangle className="h-12 w-12 text-destructive" />
      <div>
        <h2 className="text-headline-md font-bold">حدث خطأ غير متوقع</h2>
        <p className="mt-1 text-body-md text-muted-foreground">
          {error.message || "حاول مرة أخرى لاحقاً"}
        </p>
      </div>
      <Button onClick={reset}>إعادة المحاولة</Button>
    </div>
  );
}
