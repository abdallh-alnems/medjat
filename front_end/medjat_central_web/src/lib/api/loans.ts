import { apiGet, apiPost } from "./client";
import type { Loan } from "@/lib/types";

export function listLoans() {
  return apiGet<Loan[]>("app/loans/list.php");
}

export function getLoan(id: number) {
  return apiGet<Loan>("app/loans/get.php", { id });
}

export function createLoan(data: Partial<Loan>) {
  return apiPost<Loan>("app/loans/create.php", data);
}

export function approveLoan(id: number) {
  return apiPost<Loan>("app/loans/approve.php", { id });
}

export function cancelLoan(id: number) {
  return apiPost<Loan>("app/loans/cancel.php", { id });
}
