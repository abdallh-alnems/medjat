/** Shared helpers for export modules. */

/** Convert a string to a URL-safe slug (for filenames). */
export function slug(s: string): string {
  return s.replace(/\s+/g, "-").toLowerCase();
}

/** Trigger a browser download for a Blob. */
export function triggerDownload(blob: Blob, filename: string) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}
