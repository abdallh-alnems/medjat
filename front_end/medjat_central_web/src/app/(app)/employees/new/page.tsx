"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { useToastMutation } from "@/lib/hooks/use-org";
import { createEmployee } from "@/lib/api/employees";
import { useBranches, useShifts, useCategories } from "@/lib/hooks/use-org";
import { useT } from "@/lib/i18n/use-t";
import { Can } from "@/components/permissions/can";
import { LoadingState } from "@/components/ui/states";
import { toast } from "sonner";
import { Loader2 } from "lucide-react";

const schema = z.object({
  name: z.string().min(2),
  code: z.string().optional(),
  email: z.string().email().optional().or(z.literal("")),
  phone: z.string().optional(),
  branch_id: z.number().int().positive(),
  shift_id: z.number().int().optional(),
  category_id: z.number().int().optional(),
  base_salary: z.number().min(0),
  hire_date: z.string().min(1),
  job_title: z.string().optional(),
  identity_number: z.string().optional(),
});
type FormData = z.infer<typeof schema>;

export default function AddEmployeePage() {
  const router = useRouter();
  const { t } = useT();
  const [busy, setBusy] = useState(false);
  const { data: branches, isLoading: branchesLoading } = useBranches();
  const { data: shifts } = useShifts();
  const { data: categories } = useCategories();

  const {
    register,
    handleSubmit,
    setValue,
    watch,
    formState: { errors },
  } = useForm<FormData>({
    resolver: zodResolver(schema),
    defaultValues: { hire_date: new Date().toISOString().slice(0, 10), base_salary: 0 },
  });

  const mutation = useToastMutation(createEmployee, {
    successMessage: t("success"),
    invalidate: [["employees", "list"]],
    onSuccess: (emp) => router.push(`/employees/${emp.id}`),
  });

  async function onSubmit(data: FormData) {
    setBusy(true);
    try {
      await mutation.mutateAsync(data);
    } catch {
      toast.error(t("error_generic"));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Can permission="manage_employees" fallback={<LoadingState />}>
      <div className="mx-auto max-w-2xl space-y-4">
        <h1 className="text-headline-md font-bold">{t("add_employee")}</h1>
        <Card>
          <CardHeader>
            <CardTitle className="text-title-lg">{t("employee_details")}</CardTitle>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit(onSubmit)} className="space-y-3">
              <div className="grid gap-3 sm:grid-cols-2">
                <Field label={t("name")} error={errors.name && t("required")}>
                  <Input {...register("name")} />
                </Field>
                <Field label={t("code")}>
                  <Input {...register("code")} />
                </Field>
                <Field label={t("email")} error={errors.email && t("invalid_email")}>
                  <Input type="email" {...register("email")} />
                </Field>
                <Field label={t("phone")}>
                  <Input {...register("phone")} />
                </Field>
                <Field label={t("identity_number")}>
                  <Input {...register("identity_number")} />
                </Field>
                <Field label={t("job_title")}>
                  <Input {...register("job_title")} />
                </Field>
                <Field label={t("branch")} error={errors.branch_id && t("required")}>
                  {branchesLoading ? (
                    <LoadingState />
                  ) : (
                    <Select
                      value={String(watch("branch_id") ?? "")}
                      onValueChange={(v) => v && setValue("branch_id", Number(v))}
                    >
                      <SelectTrigger><SelectValue placeholder={t("branch")} /></SelectTrigger>
                      <SelectContent>
                        {(branches ?? []).map((b) => (
                          <SelectItem key={b.id} value={String(b.id)}>{b.name}</SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  )}
                </Field>
                <Field label={t("shift")}>
                  <Select
                    value={String(watch("shift_id") ?? "")}
                    onValueChange={(v) => v && setValue("shift_id", Number(v))}
                  >
                    <SelectTrigger><SelectValue placeholder={t("none")} /></SelectTrigger>
                    <SelectContent>
                      {(shifts ?? []).map((s) => (
                        <SelectItem key={s.id} value={String(s.id)}>{s.name}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </Field>
                <Field label={t("category")}>
                  <Select
                    value={String(watch("category_id") ?? "")}
                    onValueChange={(v) => v && setValue("category_id", Number(v))}
                  >
                    <SelectTrigger><SelectValue placeholder={t("none")} /></SelectTrigger>
                    <SelectContent>
                      {(categories ?? []).map((c) => (
                        <SelectItem key={c.id} value={String(c.id)}>{c.name}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </Field>
                <Field label={t("base_salary_field")} error={errors.base_salary && t("required")}>
                  <Input type="number" step="0.01" {...register("base_salary", { valueAsNumber: true })} />
                </Field>
                <Field label={t("hire_date")} error={errors.hire_date && t("required")}>
                  <Input type="date" {...register("hire_date")} />
                </Field>
              </div>
              <div className="flex justify-end gap-2 pt-2">
                <Button type="button" variant="ghost" onClick={() => router.back()}>
                  {t("cancel")}
                </Button>
                <Button type="submit" disabled={busy}>
                  {busy && <Loader2 className="h-4 w-4 animate-spin" />}
                  {t("save")}
                </Button>
              </div>
            </form>
          </CardContent>
        </Card>
      </div>
    </Can>
  );
}

function Field({
  label,
  error,
  children,
}: {
  label: string;
  error?: string;
  children: React.ReactNode;
}) {
  return (
    <div className="space-y-1.5">
      <Label>{label}</Label>
      {children}
      {error && <p className="text-label-sm text-destructive">{error}</p>}
    </div>
  );
}
