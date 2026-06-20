import { apiGet, apiPost } from "./client";
import type { RequiredDocument, DocumentSubmission } from "@/lib/types";

export function getRequiredDocuments() {
  return apiGet<RequiredDocument[]>("app/documents/get_required.php");
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

export function getRequiredSubmissions(requiredDocumentId: number) {
  return apiGet<DocumentSubmission[]>(
    "app/documents/get_required_submissions.php",
    { required_document_id: requiredDocumentId },
  );
}
