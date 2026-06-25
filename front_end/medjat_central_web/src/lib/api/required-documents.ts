import { apiGet, apiPost, unwrapList } from "./client";
import type { RequiredDocument, DocumentSubmission } from "@/lib/types";

export async function getRequiredDocuments(): Promise<RequiredDocument[]> {
  // Backend returns `{ required_documents }`.
  const raw = await apiGet<unknown>("app/documents/get_required.php");
  return unwrapList<RequiredDocument>(raw, [
    "required_documents",
    "items",
    "data",
  ]);
}

export function createRequiredDocument(data: Partial<RequiredDocument>) {
  return apiPost<RequiredDocument>("app/documents/create_required.php", data);
}

export function updateRequiredDocument(id: number, data: Partial<RequiredDocument>) {
  return apiPost<RequiredDocument>("app/documents/update_required.php", {
    id,
    ...data,
  });
}

export function deleteRequiredDocument(id: number) {
  return apiPost<{ status?: string }>("app/documents/delete_required.php", { id });
}

export function toggleRequiredDocument(id: number) {
  return apiPost<RequiredDocument>("app/documents/toggle_required.php", { id });
}

export async function getRequiredSubmissions(
  requiredDocumentId: number,
): Promise<DocumentSubmission[]> {
  // Backend returns `{ required, submissions }`.
  const raw = await apiGet<unknown>(
    "app/documents/get_required_submissions.php",
    { required_document_id: requiredDocumentId },
  );
  return unwrapList<DocumentSubmission>(raw, ["submissions", "items", "data"]);
}
