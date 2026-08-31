import {
  apiDelete,
  apiGet,
  apiPatch,
  apiPost,
  unwrapList,
} from "./client";
import type { Document } from "@/lib/types";

export async function getEmployeeDocuments(
  employeeId: number,
): Promise<Document[]> {
  // Backend returns `{ documents, required_documents }`.
  const raw = await apiGet<unknown>("v1/employees/documents", {
    employee_id: employeeId,
  });
  return unwrapList<Document>(raw, ["documents", "items", "data"]);
}

export function viewDocument(id: number) {
  return apiGet<{ file_url: string }>("v1/documents/view", { id });
}

export function uploadDocument(
  employeeId: number,
  data: { type: string; file_url: string; required_document_id?: number; expiry?: string },
) {
  return apiPost<Document>("v1/employees/documents/upload", {
    employee_id: employeeId,
    ...data,
  });
}

export function updateDocument(id: number, data: Partial<Document>) {
  return apiPatch<Document>(`v1/employees/documents/${id}`, data);
}

export function deleteDocument(id: number) {
  return apiDelete<{ status?: string }>(`v1/employees/documents/${id}`);
}

export function verifyDocument(id: number) {
  return apiPost<Document>("v1/employees/documents/verify", { id });
}

export function rejectDocument(id: number, reason?: string) {
  return apiPost<Document>("v1/employees/documents/reject", { id, reason });
}

export function requestDocument(employeeId: number, type: string) {
  return apiPost<{ status?: string }>("v1/employees/documents/request", {
    employee_id: employeeId,
    type,
  });
}
