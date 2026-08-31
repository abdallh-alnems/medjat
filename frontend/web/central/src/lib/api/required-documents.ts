import {
  apiDelete,
  apiGet,
  apiPatch,
  apiPost,
  unwrapList,
} from "./client";
import type { RequiredDocument, DocumentSubmission } from "@/lib/types";

export async function getRequiredDocuments(): Promise<RequiredDocument[]> {
  // Backend returns `{ required_documents }`.
  const raw = await apiGet<unknown>("v1/documents/required");
  return unwrapList<RequiredDocument>(raw, [
    "required_documents",
    "items",
    "data",
  ]);
}

export function createRequiredDocument(data: Partial<RequiredDocument>) {
  return apiPost<RequiredDocument>("v1/documents/required", data);
}

export function updateRequiredDocument(id: number, data: Partial<RequiredDocument>) {
  return apiPatch<RequiredDocument>(`v1/documents/required/${id}`, data);
}

export function deleteRequiredDocument(id: number) {
  return apiDelete<{ status?: string }>(`v1/documents/required/${id}`);
}

export function toggleRequiredDocument(id: number) {
  return apiPost<RequiredDocument>("v1/documents/required/toggle", { id });
}

export async function getRequiredSubmissions(
  requiredDocumentId: number,
): Promise<DocumentSubmission[]> {
  // Backend returns `{ required, submissions }`.
  const raw = await apiGet<unknown>(
    "v1/documents/required/submissions",
    { required_document_id: requiredDocumentId },
  );
  return unwrapList<DocumentSubmission>(raw, ["submissions", "items", "data"]);
}
