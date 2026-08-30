"use client";

import { use, useState } from "react";
import { notFound } from "next/navigation";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { useEmployee } from "@/lib/hooks/use-employees";
import { useToastMutation } from "@/lib/hooks/use-org";
import {
  getEmployeeDocuments,
  uploadDocument,
  verifyDocument,
  rejectDocument,
  deleteDocument,
  requestDocument,
} from "@/lib/api/documents";
import { getBiometricStatus, deleteBiometric } from "@/lib/api/biometric";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useT } from "@/lib/i18n/use-t";
import type { TKey } from "@/lib/i18n/ar";
import { usePermissions } from "@/lib/hooks/use-permissions";
import {
  LoadingState,
  ErrorState,
  EmptyState,
} from "@/components/ui/states";
import { formatDate } from "@/lib/utils";
import { useUIStore } from "@/lib/stores/ui-store";
import { Can } from "@/components/permissions/can";
import {
  CheckCircle2,
  XCircle,
  Trash2,
  Upload,
  Fingerprint,
} from "lucide-react";

export default function EmployeeDocumentsPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = use(params);
  const employeeId = Number(id);
  const { t } = useT();
  const locale = useUIStore((s) => s.locale);
  const qc = useQueryClient();
  const { can } = usePermissions();
  const invalidate = [["documents", employeeId]];

  if (!id || Number.isNaN(employeeId)) notFound();

  const { data: employee } = useEmployee(employeeId);

  const docs = useQuery({
    queryKey: ["documents", employeeId],
    queryFn: () => getEmployeeDocuments(employeeId),
  });
  const biometric = useQuery({
    queryKey: ["biometric", employeeId],
    queryFn: () => getBiometricStatus(employeeId),
  });

  const uploadMut = useToastMutation(
    (args: { employeeId: number; type: string; file_url: string; required_document_id?: number; expiry?: string }) =>
      uploadDocument(args.employeeId, args),
    {
      successMessage: t("saved"),
      invalidate,
    },
  );
  const verifyMut = useToastMutation(
    (docId: number) => verifyDocument(docId),
    { successMessage: t("verified"), invalidate },
  );
  const rejectMut = useToastMutation(
    (docId: number) => rejectDocument(docId),
    { invalidate },
  );
  const deleteMut = useToastMutation(
    (docId: number) => deleteDocument(docId),
    { invalidate },
  );
  const requestMut = useToastMutation(
    (type: string) => requestDocument(employeeId, type),
    { successMessage: t("send"), invalidate },
  );
  const deleteBio = useToastMutation(
    (_: void) => deleteBiometric(employeeId),
    {
      successMessage: t("saved"),
      invalidate: [["biometric", employeeId]],
    },
  );

  return (
    <div className="space-y-4">
      <h1 className="text-headline-md font-bold">
        {t("documents")} — {employee?.name ?? "…"}
      </h1>

      {/* Biometric (view/delete only on web) */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2 text-title-lg">
            <Fingerprint className="h-5 w-5" /> {t("biometric")}
          </CardTitle>
        </CardHeader>
        <CardContent className="flex items-center justify-between">
          <div>
            <p className="text-body-md">{t("biometric_status")}</p>
            {biometric.isLoading ? (
              <p className="text-label-sm text-muted-foreground">{t("loading")}</p>
            ) : biometric.data?.enrolled ? (
              <Badge variant="default">{t("enrolled")}</Badge>
            ) : (
              <Badge variant="secondary">{t("not_enrolled")}</Badge>
            )}
          </div>
          <Can permission="manage_employees">
            {biometric.data?.enrolled && (
              <Button variant="destructive" size="sm" onClick={() => deleteBio.mutate()}>
                <Trash2 className="h-4 w-4" /> {t("delete_biometric")}
              </Button>
            )}
          </Can>
        </CardContent>
      </Card>

      {/* Documents list */}
      <Card>
        <CardHeader>
          <CardTitle className="text-title-lg">{t("documents")}</CardTitle>
        </CardHeader>
        <CardContent className="space-y-3">
          <Can permission="manage_documents">
            <UploadForm
              onUpload={(args) => uploadMut.mutate({ employeeId, ...args })}
              onRequest={(type) => requestMut.mutate(type)}
              busy={uploadMut.isPending}
            />
          </Can>

          {docs.isLoading ? (
            <LoadingState />
          ) : docs.isError ? (
            <ErrorState />
          ) : !docs.data || docs.data.length === 0 ? (
            <EmptyState message={t("no_data")} />
          ) : (
            <ul className="divide-y">
              {docs.data.map((doc) => (
                <li key={doc.id} className="flex items-center justify-between py-2">
                  <div>
                    <p className="font-medium">{doc.type}</p>
                    <p className="text-label-sm text-muted-foreground">
                      {doc.expiry ? formatDate(doc.expiry, locale) : "—"}
                    </p>
                  </div>
                  <div className="flex items-center gap-1">
                    <Badge variant={doc.status === "verified" ? "default" : "secondary"}>
                      {t(doc.status as TKey)}
                    </Badge>
                    <Can permission="documents_verify">
                      <Button variant="ghost" size="icon-sm" onClick={() => verifyMut.mutate(doc.id)}>
                        <CheckCircle2 className="h-4 w-4 text-success" />
                      </Button>
                      <Button variant="ghost" size="icon-sm" onClick={() => rejectMut.mutate(doc.id)}>
                        <XCircle className="h-4 w-4 text-destructive" />
                      </Button>
                    </Can>
                    <Can permission="manage_documents">
                      <Button variant="ghost" size="icon-sm" onClick={() => deleteMut.mutate(doc.id)}>
                        <Trash2 className="h-4 w-4" />
                      </Button>
                    </Can>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </CardContent>
      </Card>
    </div>
  );
}

function UploadForm({
  onUpload,
  onRequest,
  busy,
}: {
  onUpload: (a: { type: string; file_url: string; expiry?: string }) => void;
  onRequest: (type: string) => void;
  busy: boolean;
}) {
  const { t } = useT();
  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        const fd = new FormData(e.currentTarget);
        onUpload({
          type: String(fd.get("type") ?? ""),
          file_url: String(fd.get("file_url") ?? ""),
          expiry: String(fd.get("expiry") ?? "") || undefined,
        });
        (e.currentTarget as HTMLFormElement).reset();
      }}
      className="grid gap-2 sm:grid-cols-4"
    >
      <Input name="type" placeholder={t("document_type")} required />
      <Input name="file_url" placeholder="URL" required />
      <Input name="expiry" type="date" />
      <Button type="submit" disabled={busy}>
        <Upload className="h-4 w-4" /> {t("upload_document")}
      </Button>
    </form>
  );
}
