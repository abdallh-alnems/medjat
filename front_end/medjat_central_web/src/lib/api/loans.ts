import { apiGet, apiPost, unwrapList, asObject } from "./client";
import type { Loan } from "@/lib/types";

export async function listLoans(): Promise<Loan[]> {
  // Backend returns `{ items }`.
  const raw = await apiGet<unknown>("app/loans/list.php");
  return unwrapList<Loan>(raw, ["items", "data"]);
}

export async function getLoan(id: number): Promise<Loan> {
  // Backend returns `{ loan }` (with installments merged in); a flat loan object
  // is accepted too.
  const raw = asObject(await apiGet<unknown>("app/loans/get.php", { id }));
  const loan = asObject(raw?.loan) ?? raw;
  if (!loan || typeof loan.id !== "number") {
    throw new Error("Unexpected loan response");
  }
  return loan as unknown as Loan;
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
