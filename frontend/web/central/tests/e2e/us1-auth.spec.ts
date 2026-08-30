import { test, expect } from "@playwright/test";

/**
 * US1 Independent Test (T036):
 *  - login → dashboard route reachable & tenant set
 *  - no-tenant account → onboarding
 *  - logout clears session
 *
 * NOTE: these run against a real dev server. Firebase auth is exercised end-to-end;
 * seed a known test account in the backend before running, or mock at the network
 * layer for CI. Skipped by default until seed credentials are provided.
 */
test.describe("US1 — auth & onboarding", () => {
  test.skip("known account logs in and reaches the dashboard", async ({
    page,
  }) => {
    await page.goto("/login");
    await page.getByLabel(/email/i).fill(process.env.E2E_EMAIL ?? "");
    await page
      .getByLabel(/password/i)
      .fill(process.env.E2E_PASSWORD ?? "");
    await page.getByRole("button", { name: /sign in|تسجيل الدخول/i }).click();
    await expect(page).toHaveURL(/\/dashboard/);
    await expect(page.getByText(/dashboard|الرئيسية/i)).toBeVisible();
  });

  test.skip("no-tenant account is routed to onboarding", async ({ page }) => {
    await page.goto("/login");
    await page.getByLabel(/email/i).fill(process.env.E2E_NO_TENANT_EMAIL ?? "");
    await page
      .getByLabel(/password/i)
      .fill(process.env.E2E_NO_TENANT_PASSWORD ?? "");
    await page.getByRole("button", { name: /sign in|تسجيل الدخول/i }).click();
    await expect(page).toHaveURL(/\/onboarding/);
    await expect(page.getByText(/create|إنشاء/i)).toBeVisible();
  });

  test.skip("logout clears the session", async ({ page }) => {
    await page.goto("/login");
    await page.getByLabel(/email/i).fill(process.env.E2E_EMAIL ?? "");
    await page.getByLabel(/password/i).fill(process.env.E2E_PASSWORD ?? "");
    await page
      .getByRole("button", { name: /sign in|تسجيل الدخول/i })
      .click();
    await page
      .getByRole("button", { name: /sign out|تسجيل الخروج/i })
      .click();
    await expect(page).toHaveURL(/\/login/);
  });
});
