"use client";

import { use, useState } from "react";
import Link from "next/link";
import { notFound } from "next/navigation";
import { useDebouncedCallback } from "@/lib/hooks/use-debounced";
import { useEmployees } from "@/lib/hooks/use-employees";
import { useCategories } from "@/lib/hooks/use-org";
import { useT } from "@/lib/i18n/use-t";
import { usePermissions } from "@/lib/hooks/use-permissions";
import {
  LoadingState,
  ErrorState,
  EmptyState,
} from "@/components/ui/states";
import { Input } from "@/components/ui/input";
import { EmployeeCard } from "@/components/employee/employee-card";
import { ArrowLeft, Search } from "lucide-react";

/** Lists the employees that belong to a single category (mirrors the
 *  Flutter CategoryEmployeesScreen). Reached from the categories settings page. */
export default function CategoryEmployeesPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = use(params);
  const categoryId = Number(id);
  if (!id || Number.isNaN(categoryId) || categoryId <= 0) notFound();

  const { t } = useT();
  const { can } = usePermissions();
  const [search, setSearch] = useState<string | undefined>(undefined);

  const { data: categories } = useCategories();
  const category = (categories ?? []).find((c) => c.id === categoryId);

  const debouncedSearch = useDebouncedCallback((v: string) => {
    setSearch(v || undefined);
  }, 300);

  const { data, isLoading, isError, refetch } = useEmployees({
    category_id: categoryId,
    search,
    per_page: 50,
  });

  const list = Array.isArray(data) ? data : data?.data ?? [];

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-2">
        <Link
          href="/settings/categories"
          className="text-brand hover:underline"
          aria-label={t("back")}
        >
          <ArrowLeft className="h-4 w-4" />
        </Link>
        <h1 className="text-headline-md font-bold">
          {category?.name ?? t("categories")}
        </h1>
      </div>

      {can("manage_employees") ? (
        <>
          <div className="relative">
            <Search className="pointer-events-none absolute start-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
            <Input
              placeholder={t("search_employees")}
              className="ps-9"
              onChange={(e) => debouncedSearch(e.target.value)}
            />
          </div>

          {isLoading ? (
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
          )}
        </>
      ) : (
        <EmptyState message={t("permission_denied")} />
      )}
    </div>
  );
}
