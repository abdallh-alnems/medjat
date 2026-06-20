import { apiGet, apiPost } from "./client";
import type { EmployeeCategory, AssetCustody } from "@/lib/types";

export function listCategories() {
  return apiGet<EmployeeCategory[]>("app/categories/list.php");
}

export function createCategory(name: string, color?: string) {
  return apiPost<EmployeeCategory>("app/categories/create.php", { name, color });
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

export function listAssets() {
  return apiGet<AssetCustody[]>("app/assets/list.php");
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
