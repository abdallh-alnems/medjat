"use client";

import { useState } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useT } from "@/lib/i18n/use-t";

interface Field {
  key: string;
  label: string;
  type?: "text" | "number" | "checkbox";
}

interface Props {
  title: string;
  fields: Field[];
  initial: Record<string, unknown> | null | undefined;
  onSave: (data: Record<string, unknown>) => void;
  pending?: boolean;
}

/** Generic key→value settings form (loads values, edits, saves). */
export function SettingsForm({ title, fields, initial, onSave, pending }: Props) {
  const { t } = useT();
  const [values, setValues] = useState<Record<string, unknown>>(
    () => (initial ? { ...initial } : {}),
  );

  return (
    <Card>
      <CardHeader>
        <CardTitle>{title}</CardTitle>
      </CardHeader>
      <CardContent className="space-y-3">
        {fields.map((f) => {
          const v = values[f.key];
          if (f.type === "checkbox") {
            return (
              <label key={f.key} className="flex items-center gap-2 text-body-md">
                <input
                  type="checkbox"
                  className="size-4"
                  checked={Boolean(v)}
                  onChange={(e) =>
                    setValues((s) => ({ ...s, [f.key]: e.target.checked }))
                  }
                />
                {f.label}
              </label>
            );
          }
          return (
            <div key={f.key} className="space-y-1.5">
              <Label>{f.label}</Label>
              <Input
                type={f.type ?? "text"}
                value={v != null ? String(v) : ""}
                onChange={(e) =>
                  setValues((s) => ({
                    ...s,
                    [f.key]:
                      f.type === "number"
                        ? e.target.value === ""
                          ? null
                          : Number(e.target.value)
                        : e.target.value,
                  }))
                }
              />
            </div>
          );
        })}
        <Button onClick={() => onSave(values)} disabled={pending}>
          {pending ? t("saving") : t("save")}
        </Button>
      </CardContent>
    </Card>
  );
}
