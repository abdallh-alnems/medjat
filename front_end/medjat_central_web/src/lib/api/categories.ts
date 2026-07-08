import { apiGet, apiPost, unwrapList } from "./client";
import type { EmployeeCategory, AssetCustody } from "@/lib/types";

export async function listCategories(): Promise<EmployeeCategory[]> {
  // Backend returns `{ categories }`.
  const raw = await apiGet<unknown>("app/categories/list.php");
  return unwrapList<EmployeeCategory>(raw, ["categories", "items", "data"]);
}

export function createCategory(
  name: string,
  color?: string,
  description?: string,
) {
  return apiPost<EmployeeCategory>("app/categories/create.php", {
    name,
    color,
    description,
  });
}

export function updateCategory(id: number, data: Partial<EmployeeCategory>) {
  return apiPost<EmployeeCategory>("app/categories/update.php", { id, ...data });
}

export function deleteCategory(id: number) {
  return apiPost<{ status?: string }>("app/categories/delete.php", { id });
}

export function assignCategory(employeeId: number, categoryId: number) {
  return apiPost<{ status?: string }>("app/categories/assign.php", {
    employee_id: employeeId,
    category_id: categoryId,
  });
}

export async function listAssets(): Promise<AssetCustody[]> {
  // Backend returns `{ items }`.
  const raw = await apiGet<unknown>("app/assets/list.php");
  return unwrapList<AssetCustody>(raw, ["items", "data"]);
}

export function createAsset(data: Partial<AssetCustody>) {
  return apiPost<AssetCustody>("app/assets/create.php", data);
}

export function updateAsset(id: number, data: Partial<AssetCustody>) {
  return apiPost<AssetCustody>("app/assets/update.php", { id, ...data });
}

export function deleteAsset(id: number) {
  return apiPost<{ status?: string }>("app/assets/delete.php", { id });
}

export function approveReturn(id: number) {
  return apiPost<AssetCustody>("app/assets/approve_return.php", { id });
}

export function rejectReturn(id: number) {
  return apiPost<AssetCustody>("app/assets/reject_return.php", { id });
}
