"use client";

import Link from "next/link";
import { useT } from "@/lib/i18n/use-t";
import {
  useRequiredDocuments,
  useCreateRequiredDocument,
  useDeleteRequiredDocument,
  useToggleRequiredDocument,
} from "@/lib/hooks/use-required-documents";
import { LoadingState, ErrorState, EmptyState } from "@/components/ui/states";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Checkbox } from "@/components/ui/checkbox";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Plus, FileText } from "lucide-react";
import { useState } from "react";

export default function RequiredDocumentsPage() {
  const { t } = useT();
  const { data, isLoading, isError, refetch } = useRequiredDocuments();
  const rows = Array.isArray(data) ? data : [];
  const create = useCreateRequiredDocument();
  const remove = useDeleteRequiredDocument();
  const toggle = useToggleRequiredDocument();

  const [name, setName] = useState("");
  const [required, setRequired] = useState(true);
  const [expires, setExpires] = useState(false);

  const add = () => {
    create.mutate(
      { name: name || "وثيقة", required, expires },
      { onSuccess: () => setName("") },
    );
  };

  return (
    <div className="space-y-4">
      <h1 className="text-headline-md font-bold">{t("required_documents")}</h1>

      <Card>
        <CardContent className="flex items-end gap-3 p-4">
          <div className="flex-1 space-y-1.5">
            <Label>{t("document_type")}</Label>
            <Input value={name} onChange={(e) => setName(e.target.value)} />
          </div>
          <label className="flex items-center gap-2 text-body-md">
            <Checkbox
              checked={required}
              onCheckedChange={(v) => setRequired(Boolean(v))}
            />
            {t("required")}
          </label>
          <label className="flex items-center gap-2 text-body-md">
            <Checkbox
              checked={expires}
              onCheckedChange={(v) => setExpires(Boolean(v))}
            />
            {t("expiry")}
          </label>
          <Button onClick={add} disabled={create.isPending}>
            <Plus className="h-4 w-4" />
            {t("add")}
          </Button>
        </CardContent>
      </Card>

      {isLoading ? (
        <LoadingState />
      ) : isError ? (
        <ErrorState onRetry={() => refetch()} />
      ) : rows.length === 0 ? (
        <EmptyState message={t("no_data")} icon={FileText} />
      ) : (
        <div className="rounded-lg border">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>{t("document_type")}</TableHead>
                <TableHead>{t("required")}</TableHead>
                <TableHead>{t("expiry")}</TableHead>
                <TableHead>{t("actions")}</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {rows.map((d) => (
                <TableRow key={d.id}>
                  <TableCell className="font-medium">
                    <Link
                      href={`/settings/required-documents/submissions?id=${d.id}`}
                      className="text-primary hover:underline"
                    >
                      {d.name}
                    </Link>
                  </TableCell>
                  <TableCell>
                    <Checkbox
                      checked={d.required}
                      onCheckedChange={() => toggle.mutate(d.id)}
                    />
                  </TableCell>
                  <TableCell>{d.expires ? t("yes") : t("no")}</TableCell>
                  <TableCell>
                    <Button variant="ghost" size="sm" onClick={() => remove.mutate(d.id)}>
                      {t("delete")}
                    </Button>
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
