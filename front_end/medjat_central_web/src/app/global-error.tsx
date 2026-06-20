"use client";

import { useEffect } from "react";

/**
 * Global error boundary — catches errors that escape the root layout (e.g. a
 * throw during layout render). Must render its own <html>/<body>.
 */
export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error("[medjat] global error:", error);
  }, [error]);

  return (
    <html lang="ar" dir="rtl">
      <body
        style={{
          margin: 0,
          minHeight: "100vh",
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          gap: "1rem",
          fontFamily: "system-ui, sans-serif",
          textAlign: "center",
          padding: "1rem",
        }}
      >
        <h1 style={{ fontSize: "1.5rem", margin: 0 }}>حدث خطأ في التطبيق</h1>
        <p style={{ color: "#64748b", margin: 0 }}>{error.message}</p>
        <button
          onClick={reset}
          style={{
            background: "#2563EB",
            color: "#fff",
            border: "none",
            borderRadius: "0.5rem",
            padding: "0.5rem 1rem",
            cursor: "pointer",
            fontSize: "0.95rem",
          }}
        >
          إعادة المحاولة
        </button>
      </body>
    </html>
  );
}
