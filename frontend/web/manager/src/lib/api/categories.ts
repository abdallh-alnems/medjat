import {
  apiDelete,
  apiGet,
  apiPatch,
  apiPost,
  unwrapList,
} from "./client";
import type { EmployeeCategory, AssetCustody } from "@/lib/types";

export async function listCategories(): Promise<EmployeeCategory[]> {
  // Backend returns `{ categories }`.
  const raw = await apiGet<unknown>("v1/categories");
  return unwrapList<EmployeeCategory>(raw, ["categories", "items", "data"]);
}

export function createCategory(
  name: string,
  color?: string,
  description?: string,
) {
  return apiPost<EmployeeCategory>("v1/categories", {
    name,
    color,
    description,
  });
}

export function updateCategory(id: number, data: Partial<EmployeeCategory>) {
  return apiPatch<EmployeeCategory>(`v1/categories/${id}`, data);
}

export function deleteCategory(id: number) {
  return apiDelete<{ status?: string }>(`v1/categories/${id}`);
}

export function assignCategory(employeeId: number, categoryId: number) {
  return apiPost<{ status?: string }>("v1/categories/assign", {
    employee_id: employeeId,
    category_id: categoryId,
  });
}

export async function listAssets(): Promise<AssetCustody[]> {
  // Backend returns `{ items }`.
  const raw = await apiGet<unknown>("v1/assets");
  return unwrapList<AssetCustody>(raw, ["items", "data"]);
}

export function createAsset(data: Partial<AssetCustody>) {
  return apiPost<AssetCustody>("v1/assets", data);
}

export function updateAsset(id: number, data: Partial<AssetCustody>) {
  return apiPatch<AssetCustody>(`v1/assets/${id}`, data);
}

export function deleteAsset(id: number) {
  return apiDelete<{ status?: string }>(`v1/assets/${id}`);
}

export function approveReturn(id: number) {
  return apiPost<AssetCustody>("v1/assets/approve-return", { id });
}

export function rejectReturn(id: number) {
  return apiPost<AssetCustody>("v1/assets/reject-return", { id });
}
