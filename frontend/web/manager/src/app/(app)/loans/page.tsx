"use client";

import { useState } from "react";
import { useT } from "@/lib/i18n/use-t";
import {
  useLoans,
  useCreateLoan,
  useApproveLoan,
  useCancelLoan,
} from "@/lib/hooks/use-loans";
import {
  LoadingState,
  ErrorState,
  EmptyState,
} from "@/components/ui/states";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetTrigger,
  SheetFooter,
  SheetClose,
} from "@/components/ui/sheet";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import type { LoanStatus } from "@/lib/types";
import type { TKey } from "@/lib/i18n/ar";
import { Plus, Banknote } from "lucide-react";

const TONE: Record<LoanStatus, "default" | "secondary" | "destructive" | "outline"> = {
  pending: "secondary",
  approved: "default",
  cancelled: "destructive",
  settled: "outline",
};

const STATUS_KEY: Record<LoanStatus, TKey> = {
  pending: "loan_pending",
  approved: "loan_approved",
  cancelled: "loan_cancelled",
  settled: "loan_settled",
};

export default function LoansPage() {
  const { t, locale } = useT();
  const { data, isLoading, isError, refetch } = useLoans();
  const create = useCreateLoan();
  const approve = useApproveLoan();
  const cancel = useCancelLoan();
  const loans = Array.isArray(data) ? data : [];

  const [open, setOpen] = useState(false);
  const [employeeId, setEmployeeId] = useState("");
  const [principal, setPrincipal] = useState("");
  const [installment, setInstallment] = useState("");

  const fmt = (n: number) =>
    new Intl.NumberFormat(locale === "ar" ? "ar-EG" : "en-GB").format(n);

  const submit = () => {
    const empId = Number(employeeId);
    const princ = Number(principal);
    const inst = Number(installment);
    if (!empId || !princ || !inst || princ <= 0 || inst <= 0) return;
    create.mutate(
      {
        employee_id: empId,
        principal: princ,
        installment: inst,
        remaining: princ,
      },
      {
        onSuccess: () => {
          setOpen(false);
          setEmployeeId("");
          setPrincipal("");
          setInstallment("");
        },
      },
    );
  };

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between gap-2">
        <h1 className="text-headline-md font-bold">{t("loans")}</h1>
        <Sheet open={open} onOpenChange={setOpen}>
          <SheetTrigger render={<Button size="sm" />}>
            <Plus className="h-4 w-4" />
            {t("new_loan")}
          </SheetTrigger>
          <SheetContent side="left" className="w-full max-w-sm space-y-4">
            <SheetHeader>
              <SheetTitle>{t("new_loan")}</SheetTitle>
            </SheetHeader>
            <div className="space-y-1.5">
              <Label>{t("employee")}</Label>
              <Input
                type="number"
                value={employeeId}
                onChange={(e) => setEmployeeId(e.target.value)}
              />
            </div>
            <div className="space-y-1.5">
              <Label>{t("principal")}</Label>
              <Input
                type="number"
                value={principal}
                onChange={(e) => setPrincipal(e.target.value)}
              />
            </div>
            <div className="space-y-1.5">
              <Label>{t("installment")}</Label>
              <Input
                type="number"
                value={installment}
                onChange={(e) => setInstallment(e.target.value)}
              />
            </div>
            <SheetFooter>
              <SheetClose render={<Button variant="outline" />}>{t("cancel")}</SheetClose>
              <Button
                onClick={submit}
                disabled={create.isPending || !employeeId || !principal || !installment}
              >
                {create.isPending ? t("saving") : t("create")}
              </Button>
            </SheetFooter>
          </SheetContent>
        </Sheet>
      </div>

      {isLoading ? (
        <LoadingState />
      ) : isError ? (
        <ErrorState onRetry={() => refetch()} />
      ) : loans.length === 0 ? (
        <EmptyState message={t("no_records")} icon={Banknote} />
      ) : (
        <div className="rounded-lg border">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>{t("name")}</TableHead>
                <TableHead>{t("principal")}</TableHead>
                <TableHead>{t("installment")}</TableHead>
                <TableHead>{t("remaining")}</TableHead>
                <TableHead>{t("status")}</TableHead>
                <TableHead>{t("actions")}</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {loans.map((l) => (
                <TableRow key={l.id}>
                  <TableCell className="font-medium">
                    {l.employee_name ?? `${t("employee")} #${l.employee_id}`}
                  </TableCell>
                  <TableCell>{fmt(l.principal)}</TableCell>
                  <TableCell>{fmt(l.installment)}</TableCell>
                  <TableCell>{fmt(l.remaining)}</TableCell>
                  <TableCell>
                    <Badge variant={TONE[l.status]}>
                      {t(STATUS_KEY[l.status])}
                    </Badge>
                  </TableCell>
                  <TableCell>
                    <div className="flex gap-1">
                      {l.status === "pending" && (
                        <Button variant="ghost" size="sm" onClick={() => approve.mutate(l.id)}>
                          {t("approve")}
                        </Button>
                      )}
                      {(l.status === "pending" || l.status === "approved") && (
                        <Button variant="ghost" size="sm" onClick={() => cancel.mutate(l.id)}>
                          {t("cancel_loan")}
                        </Button>
                      )}
                    </div>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </div>
      )}
    </div>
  );
}
