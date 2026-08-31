import { apiPost } from "./client";

export interface ImportPunchesPreview {
  preview: true;
  device_id: number;
  branch_id: number;
  readable_rows: number;
  unreadable_rows: number;
  distinct_users: number;
  first_punch: string;
  last_punch: string;
  date_order: "dmy" | "mdy" | "ymd";
  date_order_ambiguous: boolean;
  had_header: boolean;
  sample: { line: number; device_user_id: string; punched_at: string }[];
  errors: { line: number; reason: string; raw: string }[];
}

export interface ImportPunchesResult {
  preview: false;
  device_id: number;
  branch_id: number;
  read_rows: number;
  unreadable_rows: number;
  already_imported: number;
  results: {
    applied: number;
    duplicate: number;
    ignored: number;
    failed: number;
    unmatched: number;
  };
  date_order: "dmy" | "mdy" | "ymd";
  date_order_ambiguous: boolean;
  unlinked_users: number;
  errors: { line: number; reason: string; raw: string }[];
}

/**
 * Reads a punch export as text, honouring whatever encoding it was written in.
 *
 * The file is sent to the backend as a JSON string rather than as a multipart
 * upload, because the BFF proxy forwards request bodies with `request.text()` —
 * fine for text, lossy for a multipart stream. Decoding here also lets us
 * handle the UTF-16 exports some terminals produce, which a plain `file.text()`
 * would turn into mojibake before it ever left the browser.
 */
export async function readPunchFile(file: File): Promise<string> {
  const buffer = await file.arrayBuffer();
  const head = new Uint8Array(buffer.slice(0, 2));

  let encoding = "utf-8";
  if (head[0] === 0xff && head[1] === 0xfe) encoding = "utf-16le";
  else if (head[0] === 0xfe && head[1] === 0xff) encoding = "utf-16be";

  // `ignoreBOM: false` strips the BOM rather than leaving it glued to the
  // first header cell, where it would stop any column name from matching.
  return new TextDecoder(encoding, { ignoreBOM: false }).decode(buffer);
}

export function importPunches(params: {
  csvText: string;
  branchId?: number;
  deviceId?: number;
  preview: boolean;
}) {
  return apiPost<ImportPunchesPreview | ImportPunchesResult>(
    "v1/devices/import-punches",
    {
      csv_text: params.csvText,
      ...(params.branchId ? { branch_id: params.branchId } : {}),
      ...(params.deviceId ? { device_id: params.deviceId } : {}),
      preview: params.preview,
    },
  );
}
