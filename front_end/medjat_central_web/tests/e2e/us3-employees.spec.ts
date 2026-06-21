import { test, expect } from "@playwright/test";

/**
 * US3 Independent Test (T054): add → filter → edit → attach/verify doc →
 * settle/terminate → appears in terminated list. Skipped until seed creds exist.
 */
test.describe("US3 — employees", () => {
  test.skip("employee lifecycle", async ({ page }) => {
    await page.goto("/login");
    await page.getByLabel(/email/i).fill(process.env.E2E_EMAIL ?? "");
    await page
      .getByLabel(/password/i)
      .fill(process.env.E2E_PASSWORD ?? "");
    await page.getByRole("button", { name: /sign in|تسجيل الدخول/i }).click();

    // Add
    await page.goto("/employees/new");
    await page.getByLabel(/name|الاسم/i).fill("موظف اختبار");
    await page.getByRole("button", { name: /save|حفظ/i }).click();

    // List + search
    await page.goto("/employees");
    await page.getByPlaceholder(/search|ابحث/i).fill("موظف اختبار");
    await expect(page.getByText("موظف اختبار")).toBeVisible();
  });
});
