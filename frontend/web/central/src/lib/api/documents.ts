import { apiGet, apiPost, unwrapList } from "./client";
import type { Document } from "@/lib/types";

export async function getEmployeeDocuments(
  employeeId: number,
): Promise<Document[]> {
  // Backend returns `{ documents, required_documents }`.
  const raw = await apiGet<unknown>("app/employees/get_documents.php", {
    employee_id: employeeId,
  });
  return unwrapList<Document>(raw, ["documents", "items", "data"]);
}

export function viewDocument(id: number) {
  return apiGet<{ file_url: string }>("app/documents/view.php", { id });
}

export function uploadDocument(
  employeeId: number,
  data: { type: string; file_url: string; required_document_id?: number; expiry?: string },
) {
  return apiPost<Document>("app/employees/upload_document.php", {
    employee_id: employeeId,
    ...data,
  });
}

export function updateDocument(id: number, data: Partial<Document>) {
  return apiPost<Document>("app/employees/update_document.php", { id, ...data });
}

export function deleteDocument(id: number) {
  return apiPost<{ status?: string }>("app/employees/delete_document.php", {
    id,
  });
}

export function verifyDocument(id: number) {
  return apiPost<Document>("app/employees/verify_document.php", { id });
}

export function rejectDocument(id: number, reason?: string) {
  return apiPost<Document>("app/employees/reject_document.php", { id, reason });
}

export function requestDocument(employeeId: number, type: string) {
  return apiPost<{ status?: string }>("app/employees/request_document.php", {
    employee_id: employeeId,
    type,
  });
}
