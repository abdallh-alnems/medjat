import { describe, it, expect } from "vitest";
import { http, HttpResponse } from "msw";
import { server } from "../mocks/server";
import {
  listTickets,
  createTicket,
  listMessages,
  replyTicket,
  closeTicket,
} from "@/lib/api/support";
import {
  listNotifications,
  markNotificationRead,
  getNotificationPrefs,
} from "@/lib/api/notifications";
import { listAudit } from "@/lib/api/audit";

const API = "/api";

describe("support, notifications & audit contract", () => {
  it("tickets list: success", async () => {
    server.use(
      http.get(`${API}/app/support/list.php`, () =>
        HttpResponse.json([
          {
            id: 1,
            subject: "مساعدة",
            status: "open",
            created_at: "2026-06-20",
          },
        ]),
      ),
    );
    const res = await listTickets();
    expect(res[0]?.status).toBe("open");
  });

  it("create ticket: success", async () => {
    server.use(
      http.post(`${API}/app/support/create.php`, () =>
        HttpResponse.json({
          id: 1,
          subject: "موضوع",
          status: "open",
          created_at: "2026-06-20",
        }),
      ),
    );
    const res = await createTicket({ subject: "موضوع", message: "أهلاً" });
    expect(res.status).toBe("open");
  });

  it("messages with after_id: success", async () => {
    server.use(
      http.get(`${API}/app/support/messages.php`, () =>
        HttpResponse.json([
          {
            id: 5,
            ticket_id: 1,
            sender: "support",
            body: "رد",
            created_at: "2026-06-20",
          },
        ]),
      ),
    );
    const res = await listMessages(1, 4);
    expect(res[0]?.sender).toBe("support");
  });

  it("reply: success", async () => {
    server.use(
      http.post(`${API}/app/support/reply.php`, () =>
        HttpResponse.json({
          id: 6,
          ticket_id: 1,
          sender: "user",
          body: "شكراً",
          created_at: "2026-06-20",
        }),
      ),
    );
    const res = await replyTicket(1, "شكراً");
    expect(res.body).toBe("شكراً");
  });

  it("close ticket: success", async () => {
    server.use(
      http.post(`${API}/app/support/close.php`, () =>
        HttpResponse.json({ status: "ok" }),
      ),
    );
    const res = await closeTicket(1);
    expect(res.status).toBe("ok");
  });

  it("notifications list: 4xx permission-denied", async () => {
    server.use(
      http.get(`${API}/app/notifications/list.php`, () =>
        HttpResponse.json({ message: "denied" }, { status: 403 }),
      ),
    );
    const res = await listNotifications();
    expect((res as { message?: string }).message).toBe("denied");
  });

  it("mark notification read: success", async () => {
    server.use(
      http.post(`${API}/app/notifications/read.php`, () =>
        HttpResponse.json({ status: "ok" }),
      ),
    );
    const res = await markNotificationRead(1);
    expect(res.status).toBe("ok");
  });

  it("notification prefs: success", async () => {
    server.use(
      http.get(`${API}/app/auth/notification_prefs.php`, () =>
        HttpResponse.json({ email: true, push: false, in_app: true }),
      ),
    );
    const res = await getNotificationPrefs();
    expect(res.in_app).toBe(true);
  });

  it("audit list: success", async () => {
    server.use(
      http.get(`${API}/app/audit/list.php`, () =>
        HttpResponse.json([
          {
            id: 1,
            actor: "مدير",
            action: "approve",
            target: "payroll",
            created_at: "2026-06-20",
          },
        ]),
      ),
    );
    const res = await listAudit();
    expect(res[0]?.action).toBe("approve");
  });

  it("tickets list: offline rejects", async () => {
    server.use(
      http.get(`${API}/app/support/list.php`, () => HttpResponse.error()),
    );
    await expect(listTickets()).rejects.toBeDefined();
  });
});
