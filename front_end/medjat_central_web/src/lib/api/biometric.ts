import { apiGet, apiPost } from "./client";
import type { BiometricEnrollment } from "@/lib/types";

export function getBiometricStatus(employeeId: number) {
  return apiGet<BiometricEnrollment>("app/biometric/status.php", {
    employee_id: employeeId,
  });
}

/** Web deletes an enrollment only (no capture — D10). */
export function deleteBiometric(employeeId: number) {
  return apiPost<{ status?: string }>("app/biometric/delete.php", {
    employee_id: employeeId,
  });
}
