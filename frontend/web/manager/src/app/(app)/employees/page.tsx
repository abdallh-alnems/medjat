"use client";

import { useState } from "react";
import Link from "next/link";
import { useDebouncedCallback } from "@/lib/hooks/use-debounced";
import { useEmployees } from "@/lib/hooks/use-employees";
import { useT } from "@/lib/i18n/use-t";
import { usePermissions } from "@/lib/hooks/use-permissions";
import { Can } from "@/components/permissions/can";
import {
  LoadingState,
  ErrorState,
  EmptyState,
} from "@/components/ui/states";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { EmployeeCard } from "@/components/employee/employee-card";
import { FiltersSheet } from "@/components/employee/filters-sheet";
import { SortMenu } from "@/components/employee/sort-menu";
import type { EmployeeListParams } from "@/lib/api/employees";
import { Search, UserPlus } from "lucide-react";

export default function EmployeesPage() {
  const { t } = useT();
  const { can } = usePermissions();
  const [filters, setFilters] = useState<EmployeeListParams>({
    page: 1,
    per_page: 50,
  });
  const [sort, setSort] = useState("name");

  const debouncedSearch = useDebouncedCallback((v: string) => {
    setFilters((f) => ({ ...f, search: v || undefined, page: 1 }));
  }, 300);

  const { data, isLoading, isError, refetch } = useEmployees({
    ...filters,
    sort,
  });

  const list = Array.isArray(data) ? data : data?.data ?? [];

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between gap-2">
        <h1 className="text-headline-md font-bold">{t("employees")}</h1>
        <Can permission="manage_employees">
          <Button render={<Link href="/employees/new" />}>
            <UserPlus className="h-4 w-4" />
            {t("add_employee")}
          </Button>
        </Can>
      </div>

      <div className="flex items-center gap-2">
        <div className="relative flex-1">
          <Search className="pointer-events-none absolute start-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            placeholder={t("search_employees")}
            className="ps-9"
            onChange={(e) => debouncedSearch(e.target.value)}
          />
        </div>
        <FiltersSheet filters={filters} onChange={setFilters} />
        <SortMenu value={sort} onChange={setSort} />
      </div>

      {can("manage_employees") ? (
        isLoading ? (
          <LoadingState />
        ) : isError ? (
          <ErrorState onRetry={() => refetch()} />
        ) : list.length === 0 ? (
          <EmptyState message={t("no_employees")} />
        ) : (
          <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
            {list.map((emp) => (
              <EmployeeCard key={emp.id} employee={emp} />
            ))}
          </div>
        )
      ) : (
        <EmptyState message={t("permission_denied")} />
      )}
    </div>
  );
}
