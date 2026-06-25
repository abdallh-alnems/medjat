import { describe, it, expect } from "vitest";
import { http, HttpResponse } from "msw";
import { server } from "../mocks/server";
import { addWarning, deleteWarning } from "@/lib/api/warnings";
import {
  listPerformanceReviews,
  createPerformanceReview,
  deletePerformanceReview,
} from "@/lib/api/performance";

const API = "/api";

describe("warnings + performance contract", () => {
  it("warnings: add", async () => {
    server.use(
      http.post(`${API}/app/warnings/add.php`, () =>
        HttpResponse.json({ id: 1, employee_id: 1, reason: "تأخير", date: "2026-01-01" }),
      ),
    );
    const res = await addWarning(1, "تأخير");
    expect(res.id).toBe(1);
  });

  it("warnings: delete", async () => {
    server.use(
      http.post(`${API}/app/warnings/delete.php`, () =>
        HttpResponse.json({ status: "ok" }),
      ),
    );
    const res = await deleteWarning(1);
    expect(res.status).toBe("ok");
  });

  it("performance: list", async () => {
    server.use(
      http.get(`${API}/app/performance/review_list.php`, () =>
        HttpResponse.json([
          { id: 1, employee_id: 1, period: "2026-Q1", rating: 4 },
        ]),
      ),
    );
    const res = await listPerformanceReviews(1);
    expect(res[0]?.rating).toBe(4);
  });

  it("performance: create + delete", async () => {
    server.use(
      http.post(`${API}/app/performance/review_create.php`, () =>
        HttpResponse.json({ id: 2, employee_id: 1, period: "2026-Q2", rating: 5 }),
      ),
    );
    const created = await createPerformanceReview(1, {
      period: "2026-Q2",
      rating: 5,
    });
    expect(created.id).toBe(2);

    server.use(
      http.post(`${API}/app/performance/review_delete.php`, () =>
        HttpResponse.json({ status: "ok" }),
      ),
    );
    const removed = await deletePerformanceReview(2);
    expect(removed.status).toBe("ok");
  });

  it("warnings: add — permission denied (403)", async () => {
    server.use(
      http.post(`${API}/app/warnings/add.php`, () =>
        HttpResponse.json(
          { status: "error", message: "permission_denied" },
          { status: 403 },
        ),
      ),
    );
    const res = await addWarning(1, "test");
    expect(res).toHaveProperty("status", "error");
  });

  it("warnings: add — offline rejects", async () => {
    server.use(
      http.post(`${API}/app/warnings/add.php`, () => HttpResponse.error()),
    );
    await expect(addWarning(1, "test")).rejects.toBeDefined();
  });

  it("performance: list — permission denied (403)", async () => {
    server.use(
      http.get(`${API}/app/performance/review_list.php`, () =>
        HttpResponse.json(
          { status: "error", message: "permission_denied" },
          { status: 403 },
        ),
      ),
    );
    const res = await listPerformanceReviews(1);
    // List helpers always resolve to a (possibly empty) array, never an error body.
    expect(res).toEqual([]);
  });

  it("performance: list — offline rejects", async () => {
    server.use(
      http.get(`${API}/app/performance/review_list.php`, () =>
        HttpResponse.error(),
      ),
    );
    await expect(listPerformanceReviews(1)).rejects.toBeDefined();
  });
});
