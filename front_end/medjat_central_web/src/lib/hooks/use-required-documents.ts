"use client";

import { useQuery } from "@tanstack/react-query";
import { useToastMutation } from "@/lib/hooks/use-org";
import {
  getRequiredDocuments,
  createRequiredDocument,
  updateRequiredDocument,
  deleteRequiredDocument,
  toggleRequiredDocument,
  getRequiredSubmissions,
} from "@/lib/api/required-documents";
import type { RequiredDocument } from "@/lib/types";

const QK = ["required-documents"] as const;

export function useRequiredDocuments() {
  return useQuery({
    queryKey: [...QK, "list"],
    queryFn: getRequiredDocuments,
  });
}

export function useRequiredSubmissions(requiredDocumentId: number | null) {
  return useQuery({
    queryKey: [...QK, "submissions", requiredDocumentId],
    queryFn: () => getRequiredSubmissions(requiredDocumentId as number),
    enabled: requiredDocumentId != null,
  });
}

export function useCreateRequiredDocument() {
  return useToastMutation(
    (data: Partial<RequiredDocument>) => createRequiredDocument(data),
    { invalidate: [QK] },
  );
}

export function useUpdateRequiredDocument() {
  return useToastMutation(
    (args: { id: number; data: Partial<RequiredDocument> }) =>
      updateRequiredDocument(args.id, args.data),
    { invalidate: [QK] },
  );
}

export function useDeleteRequiredDocument() {
  return useToastMutation(
    (id: number) => deleteRequiredDocument(id),
    { invalidate: [QK] },
  );
}

export function useToggleRequiredDocument() {
  return useToastMutation(
    (id: number) => toggleRequiredDocument(id),
    { invalidate: [QK] },
  );
}
