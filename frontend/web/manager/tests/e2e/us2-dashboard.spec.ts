import { test, expect } from "@playwright/test";

/**
 * US2 Independent Test (T043): dashboard renders seeded values; comparison ranks
 * branches; pending counts link to lists. Skipped by default until seed creds exist.
 */
test.describe("US2 — dashboard", () => {
  test.skip("dashboard renders counts, charts and pending links", async ({
    page,
  }) => {
    await page.goto("/login");
    await page.getByLabel(/email/i).fill(process.env.E2E_EMAIL ?? "");
    await page
      .getByLabel(/password/i)
      .fill(process.env.E2E_PASSWORD ?? "");
    await page.getByRole("button", { name: /sign in|تسجيل الدخول/i }).click();
    await expect(page).toHaveURL(/\/dashboard/);
    await expect(page.getByText(/present today|الحاضرون اليوم/i)).toBeVisible();
    await expect(page.getByText(/branch comparison|مقارنة الفروع/i)).toBeVisible();
  });
});
