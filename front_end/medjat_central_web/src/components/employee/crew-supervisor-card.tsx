"use client";

/**
 * Assigns the supervisor who may record this employee's attendance on site.
 *
 * Worth being explicit about what this control does, because it is not an
 * ordinary profile field: naming a supervisor here is what lets one employee's
 * credential write another employee's attendance row. Every other employee
 * endpoint in the product acts only on its own holder. So the card says so in
 * plain language rather than presenting itself as a reporting-line dropdown.
 */

import { useState } from "react";
import { useT } from "@/lib/i18n/use-t";
import { useEmployees } from "@/lib/hooks/use-employees";
import { useToastMutation } from "@/lib/hooks/use-org";
import { setCrewSupervisor } from "@/lib/api/employees";
import type { Employee } from "@/lib/types";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

const NONE = "none";

export function CrewSupervisorCard({
  employee,
  canEdit,
}: {
  employee: Employee;
  canEdit: boolean;
}) {
  const { t } = useT();
  const { data: all } = useEmployees();
  const [value, setValue] = useState<string>(
    employee.crew_supervisor_id ? String(employee.crew_supervisor_id) : NONE,
  );

  const save = useToastMutation(
    (supervisorId: number | null) => setCrewSupervisor(employee.id, supervisorId),
    {
      successMessage: t("saved"),
      invalidate: [["employees", "detail", employee.id]],
    },
  );

  // Self-supervision is refused by the server too; excluding it here just keeps
  // an impossible option out of the list. Longer loops (A→B→A) are NOT filtered
  // — detecting those means walking the chain, which is the server's job, and a
  // half-check here would only make the refusal look arbitrary.
  const candidates: Employee[] = (all?.data ?? []).filter(
    (e: Employee) => e.id !== employee.id && e.status !== "terminated",
  );

  const current = employee.crew_supervisor_id
    ? String(employee.crew_supervisor_id)
    : NONE;
  const dirty = value !== current;

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-title-lg">{t("crew_supervisor")}</CardTitle>
      </CardHeader>
      <CardContent className="space-y-3">
        <p className="text-body-md text-muted-foreground">
          {t("crew_supervisor_hint")}
        </p>

        <Select
          value={value}
          // The Select can emit null when cleared; NONE is this component's
          // explicit "no supervisor" value, so collapse the two.
          onValueChange={(v) => setValue(v ?? NONE)}
          disabled={!canEdit || save.isPending}
        >
          <SelectTrigger>
            <SelectValue placeholder={t("crew_supervisor_none")} />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value={NONE}>{t("crew_supervisor_none")}</SelectItem>
            {candidates.map((e) => (
              <SelectItem key={e.id} value={String(e.id)}>
                {e.name}
                {e.job_title ? ` — ${e.job_title}` : ""}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>

        {canEdit && (
          <Button
            onClick={() => save.mutate(value === NONE ? null : Number(value))}
            disabled={!dirty || save.isPending}
          >
            {t("save")}
          </Button>
        )}
      </CardContent>
    </Card>
  );
}
