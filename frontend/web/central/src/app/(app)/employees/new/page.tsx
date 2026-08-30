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
import { Checkbox } from "@/components/ui/checkbox";
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
import type { TKey } from "@/lib/i18n/ar";
import { Can } from "@/components/permissions/can";
import { LoadingState } from "@/components/ui/states";
import { toast } from "sonner";
import { Loader2 } from "lucide-react";

const schema = z.object({
  name: z.string().min(2),
  phone: z.string().optional(),
  branch_id: z.number().int().positive(),
  shift_id: z.number().int().optional(),
  category_id: z.number().int().optional(),
  base_salary: z.number().min(0),
  hire_date: z.string().min(1),
  job_title: z.string().optional(),
  identity_number: z.string().optional(),
  annual_leave_days: z.number().int().optional(),
  work_start_time: z.string().optional(),
  work_end_time: z.string().optional(),
  bank_name: z.string().optional(),
  bank_account_number: z.string().optional(),
  bank_iban: z.string().optional(),
  bank_swift: z.string().optional(),
  auto_terminate_at: z.string().optional(),
});
type FormData = z.infer<typeof schema>;

// Saturday-first, ISO weekday → label key (matches company settings).
const WEEKDAYS: { value: number; key: TKey }[] = [
  { value: 6, key: "weekday_sat" },
  { value: 7, key: "weekday_sun" },
  { value: 1, key: "weekday_mon" },
  { value: 2, key: "weekday_tue" },
  { value: 3, key: "weekday_wed" },
  { value: 4, key: "weekday_thu" },
  { value: 5, key: "weekday_fri" },
];

export default function AddEmployeePage() {
  const router = useRouter();
  const { t } = useT();
  const [busy, setBusy] = useState(false);
  const [weeklyOff, setWeeklyOff] = useState<number[]>([]);
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
    defaultValues: {
      hire_date: new Date().toISOString().slice(0, 10),
      base_salary: 0,
      work_start_time: "09:00",
      work_end_time: "17:00",
    },
  });

  const mutation = useToastMutation(createEmployee, {
    successMessage: t("success"),
    invalidate: [["employees", "list"]],
    onSuccess: (emp) => router.push(`/employees/${emp.id}`),
  });

  const toggleOff = (day: number) =>
    setWeeklyOff((s) =>
      s.includes(day) ? s.filter((d) => d !== day) : [...s, day],
    );

  async function onSubmit(data: FormData) {
    setBusy(true);
    try {
      await mutation.mutateAsync({
        name: data.name,
        phone: data.phone,
        national_id: data.identity_number,
        job_title: data.job_title,
        hire_date: data.hire_date,
        branch_id: data.branch_id,
        shift_id: data.shift_id,
        category_ids: data.category_id ? [data.category_id] : [],
        base_salary: data.base_salary,
        annual_leave_days: data.annual_leave_days ?? null,
        work_start_time: data.work_start_time,
        work_end_time: data.work_end_time,
        weekly_off_days: weeklyOff,
        bank_name: data.bank_name,
        bank_account_number: data.bank_account_number,
        bank_iban: data.bank_iban,
        bank_swift: data.bank_swift,
        auto_terminate_at: data.auto_terminate_at || null,
      });
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

        <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
          {/* ── Basic info ── */}
          <Card>
            <CardHeader>
              <CardTitle className="text-title-lg">
                {t("employee_details")}
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="grid gap-3 sm:grid-cols-2">
                <Field label={t("name")} error={errors.name && t("required")}>
                  <Input {...register("name")} />
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
                <Field
                  label={t("branch")}
                  error={errors.branch_id && t("required")}
                >
                  {branchesLoading ? (
                    <LoadingState />
                  ) : (
                    <Select
                      value={String(watch("branch_id") ?? "")}
                      onValueChange={(v) => v && setValue("branch_id", Number(v))}
                    >
                      <SelectTrigger>
                        <SelectValue placeholder={t("branch")}>
                          {(v) =>
                            (branches ?? []).find((b) => String(b.id) === v)
                              ?.name ?? t("branch")
                          }
                        </SelectValue>
                      </SelectTrigger>
                      <SelectContent>
                        {(branches ?? []).map((b) => (
                          <SelectItem key={b.id} value={String(b.id)}>
                            {b.name}
                          </SelectItem>
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
                    <SelectTrigger>
                      <SelectValue placeholder={t("none")}>
                        {(v) =>
                          (shifts ?? []).find((s) => String(s.id) === v)?.name ??
                          t("none")
                        }
                      </SelectValue>
                    </SelectTrigger>
                    <SelectContent>
                      {(shifts ?? []).map((s) => (
                        <SelectItem key={s.id} value={String(s.id)}>
                          {s.name}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </Field>
                <Field label={t("category")}>
                  <Select
                    value={String(watch("category_id") ?? "")}
                    onValueChange={(v) => v && setValue("category_id", Number(v))}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder={t("none")}>
                        {(v) =>
                          (categories ?? []).find((c) => String(c.id) === v)
                            ?.name ?? t("none")
                        }
                      </SelectValue>
                    </SelectTrigger>
                    <SelectContent>
                      {(categories ?? []).map((c) => (
                        <SelectItem key={c.id} value={String(c.id)}>
                          {c.name}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </Field>
                <Field
                  label={t("base_salary_field")}
                  error={errors.base_salary && t("required")}
                >
                  <Input
                    type="number"
                    step="0.01"
                    {...register("base_salary", { valueAsNumber: true })}
                  />
                </Field>
                <Field
                  label={t("hire_date")}
                  error={errors.hire_date && t("required")}
                >
                  <Input type="date" {...register("hire_date")} />
                </Field>
                <Field label={t("annual_leave_days")}>
                  <Input
                    type="number"
                    {...register("annual_leave_days", { valueAsNumber: true })}
                  />
                </Field>
                <Field label={t("contract_end_date")}>
                  <Input type="date" {...register("auto_terminate_at")} />
                </Field>
              </div>
            </CardContent>
          </Card>

          {/* ── Work schedule ── */}
          <Card>
            <CardHeader>
              <CardTitle className="text-title-lg">
                {t("work_schedule")}
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid gap-3 sm:grid-cols-2">
                <Field label={t("work_start_time")}>
                  <Input type="time" {...register("work_start_time")} />
                </Field>
                <Field label={t("work_end_time")}>
                  <Input type="time" {...register("work_end_time")} />
                </Field>
              </div>
              <div className="space-y-2">
                <Label>{t("weekly_off_days")}</Label>
                <div className="flex flex-wrap gap-3">
                  {WEEKDAYS.map((d) => (
                    <label
                      key={d.value}
                      className="flex items-center gap-1.5 text-body-md"
                    >
                      <Checkbox
                        checked={weeklyOff.includes(d.value)}
                        onCheckedChange={() => toggleOff(d.value)}
                      />
                      {t(d.key)}
                    </label>
                  ))}
                </div>
              </div>
            </CardContent>
          </Card>

          {/* ── Bank details ── */}
          <Card>
            <CardHeader>
              <CardTitle className="text-title-lg">{t("bank_details")}</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="grid gap-3 sm:grid-cols-2">
                <Field label={t("bank_name")}>
                  <Input {...register("bank_name")} />
                </Field>
                <Field label={t("bank_account_number")}>
                  <Input {...register("bank_account_number")} />
                </Field>
                <Field label={t("bank_iban")}>
                  <Input {...register("bank_iban")} />
                </Field>
                <Field label={t("bank_swift")}>
                  <Input {...register("bank_swift")} />
                </Field>
              </div>
            </CardContent>
          </Card>

          <div className="flex justify-end gap-2">
            <Button type="button" variant="ghost" onClick={() => router.back()}>
              {t("cancel")}
            </Button>
            <Button type="submit" disabled={busy}>
              {busy && <Loader2 className="h-4 w-4 animate-spin" />}
              {t("save")}
            </Button>
          </div>
        </form>
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
