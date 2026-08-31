import {
  apiDelete,
  apiGet,
} from "./client";
import type { BiometricEnrollment } from "@/lib/types";

export function getBiometricStatus(employeeId: number) {
  return apiGet<BiometricEnrollment>("v1/biometric/status", {
    employee_id: employeeId,
  });
}

/** Web deletes an enrollment only (no capture — D10). */
export function deleteBiometric(employeeId: number) {
  return apiDelete<{ status?: string }>(`v1/biometric/${employeeId}`);
}
