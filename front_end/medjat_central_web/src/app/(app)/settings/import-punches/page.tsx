"use client";

import { useRef, useState, useSyncExternalStore } from "react";
import {
  Upload,
  FileText,
  X,
  CheckCircle2,
  AlertTriangle,
  Router,
  Loader2,
} from "lucide-react";
import { useT } from "@/lib/i18n/use-t";
import { useBranches } from "@/lib/hooks/use-org";
import {
  importPunches,
  readPunchFile,
  type ImportPunchesPreview,
  type ImportPunchesResult,
} from "@/lib/api/devices";
import { LoadingState } from "@/components/ui/states";
import { isDesktopApp } from "@/lib/desktop";
import { Input } from "@/components/ui/input";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

/**
 * Imports a punch export from a terminal of any brand.
 *
 * Two steps on purpose. A bulk import is the one action here whose mistakes are
 * both large and invisible: a file read with the day and month transposed files
 * a month of attendance on the wrong dates, and nothing afterwards looks
 * broken. So the file is always parsed and described first, and written only
 * after the admin has seen what was understood.
 */
export default function ImportPunchesPage() {
  const { t } = useT();
  const { data: branches, isLoading } = useBranches();

  const inputRef = useRef<HTMLInputElement>(null);
  const [branchId, setBranchId] = useState<string>("");
  const [fileName, setFileName] = useState<string | null>(null);
  const [csvText, setCsvText] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [preview, setPreview] = useState<ImportPunchesPreview | null>(null);
  const [result, setResult] = useState<ImportPunchesResult | null>(null);
  const [error, setError] = useState<string | null>(null);

  // Reading a terminal over the LAN needs a socket, so it exists only in the
  // desktop shell; in a browser this whole section never renders.
  const inDesktopApp = useSyncExternalStore(
    () => () => {},
    isDesktopApp,
    () => false,
  );
  const [deviceIp, setDeviceIp] = useState("");
  const [deviceBusy, setDeviceBusy] = useState(false);

  function resetOutcome() {
    setPreview(null);
    setResult(null);
    setError(null);
  }

  async function onFileChosen(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    resetOutcome();
    setFileName(file.name);
    setCsvText(await readPunchFile(file));
  }

  function clearFile() {
    setFileName(null);
    setCsvText(null);
    resetOutcome();
    if (inputRef.current) inputRef.current.value = "";
  }

  /**
   * Pulls the attendance log off a terminal on this network and drops it into
   * the same two-step flow a USB export goes through — the rows are described
   * before anything is written, exactly as if a file had been chosen.
   */
  async function readFromDevice() {
    if (!window.medjat?.readDevice) return;
    setDeviceBusy(true);
    resetOutcome();
    try {
      const res = await window.medjat.readDevice({ ip: deviceIp.trim() });
      if (!res.ok) {
        setError(res.error ?? t("error_generic"));
        return;
      }
      if (res.rows.length === 0) {
        setError("الجهاز رد لكن سجل الحضور فيه فارغ.");
        return;
      }
      setCsvText(res.csv);
      setFileName(
        `${res.device.name || res.device.ip} — ${res.rows.length} سجل` +
          (res.truncated ? " (أول 20000)" : ""),
      );
    } catch (err) {
      setError(err instanceof Error ? err.message : t("error_generic"));
    } finally {
      setDeviceBusy(false);
    }
  }

  async function run(isPreview: boolean) {
    if (!csvText || !branchId) return;
    setBusy(true);
    setError(null);
    try {
      const response = await importPunches({
        csvText,
        branchId: Number(branchId),
        preview: isPreview,
      });
      if (isPreview) {
        setPreview(response as ImportPunchesPreview);
      } else {
        setResult(response as ImportPunchesResult);
        setPreview(null);
      }
    } catch (err) {
      const message =
        err instanceof Error ? err.message : t("import_punches_failed");
      setError(message);
    } finally {
      setBusy(false);
    }
  }

  if (isLoading) return <LoadingState />;

  const canPreview = Boolean(csvText && branchId) && !busy;

  return (
    <div className="mx-auto max-w-2xl space-y-4">
      <h1 className="text-headline-md font-bold">{t("import_punches")}</h1>

      <Card>
        <CardContent className="flex gap-3 p-4 text-sm text-muted-foreground">
          <FileText className="mt-0.5 h-5 w-5 shrink-0 text-primary" />
          <p>{t("import_punches_intro")}</p>
        </CardContent>
      </Card>

      <Card>
        <CardContent className="space-y-4 p-4">
          <div className="space-y-2">
            <Label>{t("import_punches_branch")}</Label>
            <Select
              value={branchId}
              onValueChange={(v) => {
                setBranchId(v ?? "");
                // The branch decides where punches land, so a change
                // invalidates a preview taken against the previous one.
                resetOutcome();
              }}
              disabled={busy}
            >
              <SelectTrigger>
                <SelectValue placeholder="—" />
              </SelectTrigger>
              <SelectContent>
                {(branches ?? []).map((b) => (
                  <SelectItem key={b.id} value={String(b.id)}>
                    {b.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <div className="space-y-2">
            <Label>{t("import_punches_choose_file")}</Label>
            <input
              ref={inputRef}
              type="file"
              accept=".csv,.txt,.dat,.tsv,text/csv,text/plain"
              className="hidden"
              onChange={onFileChosen}
            />
            {fileName ? (
              <div className="flex items-center gap-3 rounded-md border border-primary bg-primary/5 p-3">
                <FileText className="h-5 w-5 shrink-0 text-primary" />
                <span className="flex-1 truncate text-sm font-medium">
                  {fileName}
                </span>
                <Button
                  variant="ghost"
                  size="icon"
                  onClick={clearFile}
                  disabled={busy}
                  aria-label={t("import_punches_choose_file")}
                >
                  <X className="h-4 w-4" />
                </Button>
              </div>
            ) : (
              <button
                type="button"
                onClick={() => inputRef.current?.click()}
                disabled={busy}
                className="flex w-full items-center gap-3 rounded-md border border-dashed p-4 text-start transition-colors hover:bg-muted/40"
              >
                <Upload className="h-5 w-5 shrink-0 text-muted-foreground" />
                <span className="text-sm">
                  <span className="block font-medium">
                    {t("import_punches_choose_file")}
                  </span>
                  <span className="block text-xs text-muted-foreground">
                    {t("import_punches_formats")}
                  </span>
                </span>
              </button>
            )}
          </div>

          {inDesktopApp && (
            <div className="space-y-2 border-t pt-4">
              <Label>القراءة من جهاز على الشبكة المحلية</Label>
              <div className="flex gap-2">
                <Input
                  value={deviceIp}
                  onChange={(e) => setDeviceIp(e.target.value)}
                  placeholder="192.168.1.50"
                  inputMode="decimal"
                  dir="ltr"
                  className="text-start"
                  disabled={busy || deviceBusy}
                />
                <Button
                  type="button"
                  variant="outline"
                  onClick={readFromDevice}
                  disabled={!deviceIp.trim() || busy || deviceBusy}
                >
                  {deviceBusy ? (
                    <Loader2 className="h-4 w-4 animate-spin" />
                  ) : (
                    <Router className="h-4 w-4" />
                  )}
                  قراءة
                </Button>
              </div>
              <p className="text-xs text-muted-foreground">
                يجب أن يكون هذا الجهاز على نفس شبكة جهاز البصمة. القراءة لا تمسح
                سجل الجهاز، وتكرار الاستيراد آمن.
              </p>
            </div>
          )}
        </CardContent>
      </Card>

      {error && (
        <Card className="border-destructive">
          <CardContent className="flex gap-3 p-4 text-sm">
            <AlertTriangle className="mt-0.5 h-5 w-5 shrink-0 text-destructive" />
            <p>{error}</p>
          </CardContent>
        </Card>
      )}

      {preview && (
        <Card>
          <CardHeader>
            <CardTitle className="text-base">
              {t("import_punches_preview")}
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-1 text-sm">
            <Row
              label={t("import_punches_readable")}
              value={preview.readable_rows}
            />
            <Row
              label={t("import_punches_users")}
              value={preview.distinct_users}
            />
            <Row
              label={t("import_punches_period")}
              value={`${preview.first_punch.slice(0, 10)} → ${preview.last_punch.slice(0, 10)}`}
            />
            {preview.unreadable_rows > 0 && (
              <Row
                label={t("import_punches_unreadable")}
                value={preview.unreadable_rows}
                warn
              />
            )}
            {/* The one genuinely ambiguous thing in these files, said out loud
                rather than assumed silently — filing April as March is
                invisible once it is done. */}
            {preview.date_order_ambiguous && (
              <p className="mt-3 rounded-md bg-amber-500/10 p-3 text-xs leading-relaxed">
                {t("import_punches_date_ambiguous")}
              </p>
            )}
          </CardContent>
        </Card>
      )}

      {result && (
        <Card className="border-emerald-600">
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-base">
              <CheckCircle2 className="h-5 w-5 text-emerald-600" />
              {t("import_punches_done")}
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-1 text-sm">
            <Row
              label={t("import_punches_applied")}
              value={result.results.applied}
            />
            {result.already_imported > 0 && (
              <Row
                label={t("import_punches_already")}
                value={result.already_imported}
              />
            )}
            {/* Not a failure: terminal user ids nobody has matched to an
                employee yet. Linking them replays the punches automatically. */}
            {result.results.unmatched > 0 && (
              <>
                <Row
                  label={t("import_punches_unmatched")}
                  value={result.results.unmatched}
                  warn
                />
                <p className="mt-3 text-xs leading-relaxed text-muted-foreground">
                  {t("import_punches_link_hint")}
                </p>
              </>
            )}
            <div className="pt-3">
              <Button variant="outline" onClick={clearFile}>
                {t("import_punches_another")}
              </Button>
            </div>
          </CardContent>
        </Card>
      )}

      {!result &&
        (preview ? (
          <Button className="w-full" onClick={() => run(false)} disabled={busy}>
            {t("import_punches_confirm")}
          </Button>
        ) : (
          <Button
            className="w-full"
            onClick={() => run(true)}
            disabled={!canPreview}
          >
            {t("import_punches_check")}
          </Button>
        ))}
    </div>
  );
}

function Row({
  label,
  value,
  warn,
}: {
  label: string;
  value: string | number;
  warn?: boolean;
}) {
  return (
    <div className="flex items-center justify-between py-0.5">
      <span className="text-muted-foreground">{label}</span>
      <span
        className={`font-medium tabular-nums ${warn ? "text-amber-600" : ""}`}
      >
        {value}
      </span>
    </div>
  );
}
