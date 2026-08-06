export type AssetStatus = "assigned" | "return_requested" | "returned";

export interface AssetCustody {
  id: number;
  name: string;
  employee_id?: number | null;
  employee_name?: string | null;
  status: AssetStatus;
  value?: number | null;
}

export interface AuditLogEntry {
  id: number;
  actor: string;
  action: string;
  target?: string | null;
  created_at: string;
}

export interface Notification {
  id: number;
  title: string;
  body: string;
  read: boolean;
  created_at: string;
  data?: Record<string, unknown> | null;
}

export interface NotificationPrefs {
  email: boolean;
  push: boolean;
  in_app: boolean;
}

export interface SupportTicket {
  id: number;
  subject: string;
  status: "open" | "closed";
  created_at: string;
}

export interface SupportMessage {
  id: number;
  ticket_id: number;
  /** The backend column is `sender_type`; `sender` is kept for older payloads. */
  sender?: "user" | "support";
  sender_type?: "user" | "support" | "system";
  body: string;
  created_at: string;
  /** Stored path; the file is fetched through the authenticated endpoint. */
  attachment_url?: string | null;
  attachment_name?: string | null;
}
