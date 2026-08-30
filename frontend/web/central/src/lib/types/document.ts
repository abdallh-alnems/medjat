export type DocumentStatus = "pending" | "verified" | "rejected" | "expired";

export interface Document {
  id: number;
  employee_id: number;
  required_document_id?: number | null;
  type: string;
  file_url: string;
  status: DocumentStatus;
  expiry?: string | null;
  uploaded_at: string;
}

export interface DocumentSubmission {
  id: number;
  required_document_id: number;
  employee_name: string;
  status: DocumentStatus;
  uploaded_at: string;
}

export interface RequiredDocument {
  id: number;
  name: string;
  required: boolean;
  expires: boolean;
}

export interface ComplianceItem {
  id: number;
  employee_id: number;
  employee_name: string;
  type: string;
  status: "expiring_soon" | "expired" | "missing";
  expiry?: string | null;
}

export interface DocumentStats {
  total: number;
  verified: number;
  pending: number;
  rejected: number;
  expiring_soon: number;
  expired: number;
  missing: number;
}
